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

/// @title MfT NFT Resale — owners sell NFTs, floor = LP value inside
/// @notice 50% to seller, then 1% platform fee, 50% LP→NFT, 20% artist, 30% LP→community
contract NFTResale {
    IRouter public constant router = IRouter(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    address public constant AZOS = 0x3595ca37596D5895B70EFAB592ac315D5B9809B2;
    address public constant MFT  = 0x8FB87d13B40B1A67B22ED1a17e2835fe7e3a9bA3;
    address public constant AZOS_MFT_PAIR = 0xEcC664757dA0C71ba32DFED527580A26783b6697;

    address public owner;
    address public platformWallet;
    address public communityWallet;

    uint public constant PLATFORM_FEE_BPS = 100; // 1% of ecosystem half

    struct Listing {
        address seller;
        address nftContract;
        uint tokenId;
        uint amount;
        uint priceAzos;
        address artistWallet;
        bool active;
    }

    uint public nextListingId;
    mapping(uint => Listing) public listings;

    event Listed(uint indexed listingId, address indexed seller, address nftContract, uint tokenId, uint amount, uint priceAzos, address artistWallet);
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

    /// @notice Get the AZOS value of AZOS/MfT LP tokens held by an NFT contract
    /// @dev Reads on-chain pair reserves to compute value. Only counts Base-side AZOS/MfT LP.
    function getLpValue(address nftContract) public view returns (uint) {
        uint lpBalance = IUniswapV2Pair(AZOS_MFT_PAIR).balanceOf(nftContract);
        if (lpBalance == 0) return 0;
        uint supply = IUniswapV2Pair(AZOS_MFT_PAIR).totalSupply();
        if (supply == 0) return 0;
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(AZOS_MFT_PAIR).getReserves();
        address token0 = IUniswapV2Pair(AZOS_MFT_PAIR).token0();
        uint azosReserve = token0 == AZOS ? uint(reserve0) : uint(reserve1);
        // LP value ≈ 2 * NFT's share of AZOS reserve (50/50 pool)
        return (lpBalance * azosReserve * 2) / supply;
    }

    /// @notice List an NFT for resale. Price must be >= LP value inside the NFT.
    function list(
        address nftContract,
        uint tokenId,
        uint amount,
        uint priceAzos,
        address artistWallet
    ) external returns (uint listingId) {
        uint floor = getLpValue(nftContract);
        // Floor is at least $5 even if no LP inside
        if (floor < 5e18) floor = 5e18;
        require(priceAzos >= floor, "Price below LP floor");
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
            priceAzos: priceAzos,
            artistWallet: artistWallet,
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, amount, priceAzos, artistWallet);
    }

    /// @notice Total AZOS buyer must pay (listing price + 1% platform fee on top)
    function totalCost(uint listingId) external view returns (uint) {
        Listing storage l = listings[listingId];
        return l.priceAzos + (l.priceAzos * PLATFORM_FEE_BPS) / 10000;
    }

    /// @notice Buy a listed NFT. Buyer pays price + 1% fee. 50% to seller, 50% to ecosystem.
    function buy(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        l.active = false;

        // 1% platform fee added ON TOP of listing price
        uint fee = (l.priceAzos * PLATFORM_FEE_BPS) / 10000;
        uint total = l.priceAzos + fee;

        // Pull price + fee from buyer
        IERC20(AZOS).transferFrom(msg.sender, address(this), total);

        // Platform fee to platform wallet
        IERC20(AZOS).transfer(platformWallet, fee);

        // ── 50% to seller ──
        uint toSeller = l.priceAzos / 2;
        IERC20(AZOS).transfer(l.seller, toSeller);

        // ── Remaining 50% = ecosystem pot (no fee taken from this) ──
        uint pot = l.priceAzos - toSeller;

        // 50% LP→NFT, 20% artist, 30% LP→community
        uint forNftLp = (pot * 50) / 100;
        uint forArtist = (pot * 20) / 100;
        uint forCommunityLp = pot - forNftLp - forArtist;

        // 20% AZOS to artist
        IERC20(AZOS).transfer(l.artistWallet, forArtist);

        // 50% → AZOS/MfT LP → NFT contract (stat boost)
        uint lpToNft = _makeLP(forNftLp, l.nftContract);

        // 30% → AZOS/MfT LP → community wallet
        uint lpToCommunity = _makeLP(forCommunityLp, communityWallet);

        // Refund any LP dust to buyer
        _refundDust(AZOS);
        _refundDust(MFT);

        // Transfer NFT to buyer
        IERC1155(l.nftContract).safeTransferFrom(address(this), msg.sender, l.tokenId, l.amount, "");

        emit Sold(listingId, msg.sender, toSeller, lpToNft, lpToCommunity, forArtist);
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

    /// @dev Swap half AZOS→MfT, add AZOS/MfT liquidity, send LP to `to`
    function _makeLP(uint azosAmount, address to) internal returns (uint liquidity) {
        uint half = azosAmount / 2;

        IERC20(AZOS).approve(address(router), half);
        address[] memory path = new address[](2);
        path[0] = AZOS;
        path[1] = MFT;
        router.swapExactTokensForTokens(half, 0, path, address(this), block.timestamp + 300);

        uint balAzos = azosAmount - half;
        uint balMft = IERC20(MFT).balanceOf(address(this));
        IERC20(AZOS).approve(address(router), balAzos);
        IERC20(MFT).approve(address(router), balMft);

        (,, liquidity) = router.addLiquidity(
            AZOS, MFT,
            balAzos, balMft,
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

    /// @notice ERC-165: declare supported interfaces
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x4e2312e0  // ERC1155Receiver
            || interfaceId == 0x01ffc9a7; // ERC165
    }

    function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
