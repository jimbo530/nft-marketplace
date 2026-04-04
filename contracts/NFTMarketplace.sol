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
    function decimals() external view returns (uint8);
}

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint id, uint amount, bytes calldata data) external;
    function balanceOf(address account, uint id) external view returns (uint);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

/// @title MfT NFT Marketplace — AZOS stablecoin payments, LP stat boosts
/// @notice Sells ERC-1155 NFTs. Payment splits: 1% platform, 50% LP→NFT, 20% artist, 30% LP→community
contract NFTMarketplace {
    IRouter public constant router = IRouter(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
    address public constant AZOS = 0x3595ca37596D5895B70EFAB592ac315D5B9809B2;
    address public constant MFT  = 0x8FB87d13B40B1A67B22ED1a17e2835fe7e3a9bA3;

    address public owner;
    address public platformWallet;
    address public communityWallet;

    uint public constant MIN_PRICE = 5e18; // $5 in AZOS (18 decimals)

    struct Listing {
        address seller;
        address nftContract;
        uint tokenId;
        uint amount;        // ERC-1155 quantity
        uint priceAzos;     // total price in AZOS
        address artistWallet;
        bool active;
    }

    uint public nextListingId;
    mapping(uint => Listing) public listings;

    event Listed(uint indexed listingId, address indexed seller, address nftContract, uint tokenId, uint amount, uint priceAzos, address artistWallet);
    event Sold(uint indexed listingId, address indexed buyer, uint lpToNft, uint lpToCommunity, uint toArtist);
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

    /// @notice List an ERC-1155 NFT for sale
    /// @param nftContract The ERC-1155 contract address
    /// @param tokenId The token ID to sell
    /// @param amount How many of this token to sell
    /// @param priceAzos Price in AZOS (must be >= $5)
    /// @param artistWallet Wallet that receives 20% of net sale
    function list(
        address nftContract,
        uint tokenId,
        uint amount,
        uint priceAzos,
        address artistWallet
    ) external returns (uint listingId) {
        require(priceAzos >= MIN_PRICE, "Price below $5 minimum");
        require(amount > 0, "Zero amount");
        require(artistWallet != address(0), "No artist wallet");
        require(IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");

        // Escrow: transfer NFT to marketplace
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

    /// @notice Buy a listed NFT with AZOS
    /// @param listingId The listing to purchase
    function buy(uint listingId) external {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        l.active = false;

        // Pull AZOS from buyer
        IERC20(AZOS).transferFrom(msg.sender, address(this), l.priceAzos);

        // Split: 50% LP→NFT, 20% artist, 30% LP→community (no platform fee on ToT sales)
        uint forNftLp = (l.priceAzos * 50) / 100;
        uint forArtist = (l.priceAzos * 20) / 100;
        uint forCommunityLp = l.priceAzos - forNftLp - forArtist; // 30% (absorbs rounding)

        // Send 20% AZOS to artist
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

        emit Sold(listingId, msg.sender, lpToNft, lpToCommunity, forArtist);
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

        // Swap half AZOS → MfT
        IERC20(AZOS).approve(address(router), half);
        address[] memory path = new address[](2);
        path[0] = AZOS;
        path[1] = MFT;
        router.swapExactTokensForTokens(half, 0, path, address(this), block.timestamp + 300);

        // Add liquidity with remaining AZOS + all MfT
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

    /// @notice Update wallets
    function setPlatformWallet(address w) external onlyOwner { platformWallet = w; }
    function setCommunityWallet(address w) external onlyOwner { communityWallet = w; }
    function transferOwnership(address newOwner) external onlyOwner { owner = newOwner; }

    /// @notice Rescue stuck tokens
    function rescue(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    /// @notice ERC-165: declare supported interfaces
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x4e2312e0  // ERC1155Receiver
            || interfaceId == 0x01ffc9a7; // ERC165
    }

    /// @notice Required to receive ERC-1155 tokens
    function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
