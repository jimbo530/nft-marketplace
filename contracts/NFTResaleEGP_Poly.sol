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
}

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint id, uint amount, bytes calldata data) external;
    function balanceOf(address account, uint id) external view returns (uint);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

/// @title MfT NFT Resale — Elven Emporium (Polygon) — WETH payments, EGP/PR25 LP building
/// @notice 50% to seller, then 50% LP→NFT, 20% artist, 30% LP→community. 1% platform fee on top.
contract NFTResaleEGP_Poly {
    IRouter  public constant router   = IRouter(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    address  public constant WETH     = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address  public constant EGP      = 0x64f6F111E9Fdb753877f17f399b759De97379170;
    address  public constant PR25     = 0x72E4327F592E9Cb09d5730a55D1D68De144aF53C;

    address public owner;
    address public platformWallet;
    address public communityWallet;

    uint public constant PLATFORM_FEE_BPS = 100; // 1%

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

    function totalCost(uint listingId) external view returns (uint) {
        Listing storage l = listings[listingId];
        if (l.seller == owner) return l.priceWeth;
        return l.priceWeth + (l.priceWeth * PLATFORM_FEE_BPS) / 10000;
    }

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

        uint forNftLp       = (pot * 50) / 100;
        uint forArtist      = (pot * 20) / 100;
        uint forCommunityLp = pot - forNftLp - forArtist;

        IERC20(WETH).transfer(l.artistWallet, forArtist);

        _makeLP(forNftLp, l.nftContract);
        _makeLP(forCommunityLp, communityWallet);

        _refundDust(WETH);
        _refundDust(EGP);
        _refundDust(PR25);

        IERC1155(l.nftContract).safeTransferFrom(address(this), msg.sender, l.tokenId, l.amount, "");

        emit Sold(listingId, msg.sender, toSeller, forNftLp, forCommunityLp, forArtist);
    }

    function cancel(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        require(msg.sender == l.seller || msg.sender == owner, "Not authorized");
        l.active = false;

        IERC1155(l.nftContract).safeTransferFrom(address(this), l.seller, l.tokenId, l.amount, "");
        emit Cancelled(listingId);
    }

    function _makeLP(uint wethAmount, address to) internal returns (uint liquidity) {
        uint half = wethAmount / 2;

        IERC20(WETH).approve(address(router), half);
        address[] memory pathEgp = new address[](3);
        pathEgp[0] = WETH;
        pathEgp[1] = PR25;
        pathEgp[2] = EGP;
        router.swapExactTokensForTokens(half, 0, pathEgp, address(this), block.timestamp + 300);

        uint otherHalf = wethAmount - half;
        IERC20(WETH).approve(address(router), otherHalf);
        address[] memory pathPr25 = new address[](2);
        pathPr25[0] = WETH;
        pathPr25[1] = PR25;
        router.swapExactTokensForTokens(otherHalf, 0, pathPr25, address(this), block.timestamp + 300);

        uint balEgp  = IERC20(EGP).balanceOf(address(this));
        uint balPr25 = IERC20(PR25).balanceOf(address(this));
        IERC20(EGP).approve(address(router), balEgp);
        IERC20(PR25).approve(address(router), balPr25);

        (,, liquidity) = router.addLiquidity(
            EGP, PR25,
            balEgp, balPr25,
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
