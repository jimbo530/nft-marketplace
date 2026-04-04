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

/// @title MfT NFT Resale (Polygon) — WETH payments, WETH/IGS LP building
/// @notice 50% to seller, then 50% LP→NFT, 20% artist, 30% LP→community. 1% platform fee on top.
contract NFTResalePoly {
    IRouter  public constant router   = IRouter(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    address  public constant WETH     = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address  public constant IGS      = 0xE302672798D12e7F68c783dB2c2d5E6B48ccf3ce;
    address  public constant WETH_IGS = 0x94352F443fa77545057F23794A791FaecA7a4c8f;

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

    /// @notice Get the WETH value of WETH/IGS LP tokens held by an NFT contract
    function getLpValue(address nftContract) public view returns (uint) {
        uint lpBalance = IUniswapV2Pair(WETH_IGS).balanceOf(nftContract);
        if (lpBalance == 0) return 0;
        uint supply = IUniswapV2Pair(WETH_IGS).totalSupply();
        if (supply == 0) return 0;
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(WETH_IGS).getReserves();
        address token0 = IUniswapV2Pair(WETH_IGS).token0();
        uint wethReserve = token0 == WETH ? uint(reserve0) : uint(reserve1);
        return (lpBalance * wethReserve * 2) / supply;
    }

    /// @notice List an NFT for resale. Price in WETH (18 decimals).
    function list(
        address nftContract,
        uint tokenId,
        uint amount,
        uint priceWeth,
        address artistWallet
    ) external returns (uint listingId) {
        uint floor = getLpValue(nftContract);
        require(priceWeth >= floor, "Price below LP floor");
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

    /// @notice Effective price = max(listedPrice, current LP floor). Price only goes up.
    function effectivePrice(uint listingId) public view returns (uint) {
        Listing storage l = listings[listingId];
        uint floor = getLpValue(l.nftContract);
        return l.priceWeth > floor ? l.priceWeth : floor;
    }

    /// @notice Total WETH buyer must pay. Uses effective price (LP-adjusted).
    function totalCost(uint listingId) external view returns (uint) {
        uint ep = effectivePrice(listingId);
        Listing storage l = listings[listingId];
        if (l.seller == owner) return ep;
        return ep + (ep * PLATFORM_FEE_BPS) / 10000;
    }

    /// @notice Buy a listed NFT. Price auto-adjusts upward if LP floor exceeds listed price.
    function buy(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        l.active = false;

        uint ep = effectivePrice(listingId);
        bool primary = (l.seller == owner);
        uint fee;
        uint total;
        uint toSeller;
        uint pot;

        if (primary) {
            // Primary sale: no fee, no seller cut, 100% to ecosystem
            fee = 0;
            total = ep;
            toSeller = 0;
            pot = ep;
        } else {
            // Resale: 1% fee on top, 50% seller, 50% ecosystem
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

        // 50% → WETH/IGS LP → NFT contract (stat boost)
        _makeLP(forNftLp, l.nftContract);

        // 30% → WETH/IGS LP ��� community wallet
        _makeLP(forCommunityLp, communityWallet);

        // Refund dust
        _refundDust(WETH);
        _refundDust(IGS);

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

    /// @dev Swap half WETH→IGS, add WETH/IGS liquidity, send LP to `to`
    function _makeLP(uint wethAmount, address to) internal returns (uint liquidity) {
        uint half = wethAmount / 2;

        IERC20(WETH).approve(address(router), half);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = IGS;
        router.swapExactTokensForTokens(half, 0, path, address(this), block.timestamp + 300);

        uint balWeth = wethAmount - half;
        uint balIgs  = IERC20(IGS).balanceOf(address(this));
        IERC20(WETH).approve(address(router), balWeth);
        IERC20(IGS).approve(address(router), balIgs);

        (,, liquidity) = router.addLiquidity(
            WETH, IGS,
            balWeth, balIgs,
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
