// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouter {
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory);
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint, uint, uint);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function totalSupply() external view returns (uint);
}

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint id, uint amount, bytes calldata data) external;
    function balanceOf(address account, uint id) external view returns (uint);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function totalSupply() external view returns (uint);
    function balanceOf(address) external view returns (uint);
}

/// @title MfT NFT Resale (Polygon) — WETH payments, IGS/PR25 LP building
/// @notice 50% to seller, then 50% LP→NFT, 20% artist, 30% LP→community. 1% platform fee on top.
contract NFTResalePoly {
    IRouter  public constant router   = IRouter(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    address  public constant WETH     = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address  public constant IGS      = 0xE302672798D12e7F68c783dB2c2d5E6B48ccf3ce;
    address  public constant PR25     = 0x72E4327F592E9Cb09d5730a55D1D68De144aF53C;
    address  public constant IGS_PR25 = 0xaB9DC44b75F87f40421120e8E1228076123f2735;

    address public owner;
    address public platformWallet;
    address public communityWallet;

    uint public constant PLATFORM_FEE_BPS = 100; // 1% of ecosystem half

    struct Listing {
        address seller;
        address nftContract;
        uint tokenId;
        uint amount;
        uint priceWeth;
        address artistWallet;
        bool active;
    }

    uint public nextListingId;
    mapping(uint => Listing) public listings;

    event Listed(uint indexed listingId, address indexed seller, address nftContract, uint tokenId, uint amount, uint priceWeth, address artistWallet);
    event Sold(uint indexed listingId, address indexed buyer, uint toSeller, uint lpToNft, uint lpToCommunity, uint toArtist);
    event Cancelled(uint indexed listingId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _platformWallet, address _communityWallet) {
        owner = msg.sender;
        platformWallet = _platformWallet;
        communityWallet = _communityWallet;
    }

    /// @notice List an NFT for resale. Price in WETH (18 decimals).
    function list(
        address nftContract,
        uint tokenId,
        uint amount,
        uint priceWeth,
        address artistWallet
    ) external returns (uint listingId) {
        require(amount > 0, "Zero amount");
        require(artistWallet != address(0), "No artist wallet");
        require(IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)), "Not approved");

        IERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            priceWeth: priceWeth,
            artistWallet: artistWallet,
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, amount, priceWeth, artistWallet);
    }

    /// @notice Total WETH buyer must pay.
    function totalCost(uint listingId) external view returns (uint) {
        Listing storage l = listings[listingId];
        if (l.seller == owner) return l.priceWeth;
        return l.priceWeth + (l.priceWeth * PLATFORM_FEE_BPS) / 10000;
    }

    /// @notice Buy a listed NFT. Payment in WETH, LP built as IGS/PR25.
    function buy(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        l.active = false;

        uint ep = l.priceWeth;
        bool primary = (l.seller == owner);
        uint fee;
        uint total;
        uint toSeller;
        uint pot;

        if (primary) {
            fee = 0;
            total = ep;
            toSeller = 0;
            pot = ep;
        } else {
            fee = (ep * PLATFORM_FEE_BPS) / 10000;
            total = ep + fee;
            toSeller = ep / 2;
            pot = ep - toSeller;
        }

        IERC20(WETH).transferFrom(msg.sender, address(this), total);

        if (fee > 0) IERC20(WETH).transfer(platformWallet, fee);
        if (toSeller > 0) IERC20(WETH).transfer(l.seller, toSeller);

        // 50% LP→NFT, 20% artist, 30% LP→community
        uint forNftLp      = (pot * 50) / 100;
        uint forArtist     = (pot * 20) / 100;
        uint forCommunityLp = pot - forNftLp - forArtist;

        // 20% WETH to artist
        IERC20(WETH).transfer(l.artistWallet, forArtist);

        // 50% → IGS/PR25 LP → NFT contract (stat boost)
        _makeLP(forNftLp, l.nftContract);

        // 30% → IGS/PR25 LP → community wallet
        _makeLP(forCommunityLp, communityWallet);

        // Refund dust
        _refundDust(WETH);
        _refundDust(IGS);
        _refundDust(PR25);

        // Transfer NFT to buyer
        IERC1155(l.nftContract).safeTransferFrom(address(this), msg.sender, l.tokenId, l.amount, "");

        emit Sold(listingId, msg.sender, toSeller, forNftLp, forCommunityLp, forArtist);
    }

    /// @notice Cancel a listing and return NFT to seller
    function cancel(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        require(msg.sender == l.seller || msg.sender == owner, "Not authorized");
        l.active = false;

        IERC1155(l.nftContract).safeTransferFrom(address(this), l.seller, l.tokenId, l.amount, "");
        emit Cancelled(listingId);
    }

    /// @dev Swap WETH → IGS (half) and WETH → PR25 (half), add IGS/PR25 liquidity, send LP to `to`
    function _makeLP(uint wethAmount, address to) internal returns (uint liquidity) {
        uint half = wethAmount / 2;

        // Swap half WETH → IGS
        IERC20(WETH).approve(address(router), half);
        address[] memory pathIgs = new address[](2);
        pathIgs[0] = WETH;
        pathIgs[1] = IGS;
        router.swapExactTokensForTokens(half, 0, pathIgs, address(this), block.timestamp + 300);

        // Swap other half WETH → PR25
        uint otherHalf = wethAmount - half;
        IERC20(WETH).approve(address(router), otherHalf);
        address[] memory pathPr25 = new address[](2);
        pathPr25[0] = WETH;
        pathPr25[1] = PR25;
        router.swapExactTokensForTokens(otherHalf, 0, pathPr25, address(this), block.timestamp + 300);

        // Add IGS/PR25 liquidity
        uint balIgs  = IERC20(IGS).balanceOf(address(this));
        uint balPr25 = IERC20(PR25).balanceOf(address(this));
        IERC20(IGS).approve(address(router), balIgs);
        IERC20(PR25).approve(address(router), balPr25);

        (,, liquidity) = router.addLiquidity(
            IGS, PR25,
            balIgs, balPr25,
            0, 0,
            to,
            block.timestamp + 300
        );
    }

    function _refundDust(address token) internal {
        uint bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(msg.sender, bal);
    }

    function setPlatformWallet(address w) external onlyOwner { platformWallet = w; }
    function setCommunityWallet(address w) external onlyOwner { communityWallet = w; }
    function transferOwnership(address newOwner) external onlyOwner { owner = newOwner; }

    function rescue(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x4e2312e0 || interfaceId == 0x01ffc9a7;
    }

    function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
