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

/// @title NFT Power-Up (Elven) — WETH → EGP/JCGWR LP → NFT
/// @notice Buys EGP + JCGWR (trees), creates LP, sends to NFT contract to boost backing
contract PowerUpElven {
    IRouter public constant router = IRouter(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    address public constant WETH   = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant EGP    = 0x64f6F111E9Fdb753877f17f399b759De97379170;
    address public constant JCGWR  = 0xACe15DA4edCEc83c98b1fc196fc1Dc44c5C429ca;

    event PoweredUp(address indexed user, address indexed nftContract, uint wethSpent, uint lpCreated);

    /// @notice Spend WETH to create EGP/JCGWR LP and send it to an NFT contract
    function powerUp(address nftContract, uint wethAmount) external {
        require(wethAmount > 0, "Zero amount");
        IERC20(WETH).transferFrom(msg.sender, address(this), wethAmount);

        uint half = wethAmount / 2;
        _swapWethTo(EGP, half);
        _swapWethTo(JCGWR, wethAmount - half);

        uint lpCreated = _addLpAndSend(nftContract);

        _refund(WETH);
        _refund(EGP);
        _refund(JCGWR);

        emit PoweredUp(msg.sender, nftContract, wethAmount, lpCreated);
    }

    function _swapWethTo(address tokenOut, uint amount) internal {
        IERC20(WETH).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenOut;
        router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp + 300);
    }

    function _addLpAndSend(address to) internal returns (uint liquidity) {
        uint balEgp   = IERC20(EGP).balanceOf(address(this));
        uint balJcgwr = IERC20(JCGWR).balanceOf(address(this));
        IERC20(EGP).approve(address(router), balEgp);
        IERC20(JCGWR).approve(address(router), balJcgwr);
        (,, liquidity) = router.addLiquidity(EGP, JCGWR, balEgp, balJcgwr, 0, 0, to, block.timestamp + 300);
    }

    function _refund(address token) internal {
        uint bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(msg.sender, bal);
    }
}
