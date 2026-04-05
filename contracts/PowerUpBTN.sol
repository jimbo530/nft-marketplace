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

/// @title NFT Power-Up (BTN) — WETH -> BTN/PR25 LP -> NFT
/// @notice Buys BTN + PR25, creates LP, sends to NFT contract to boost backing
contract PowerUpBTN {
    IRouter public constant router = IRouter(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    address public constant WETH   = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant BTN    = 0xD7C584D40216576f1d8651Eab8bEF9DE69497666;
    address public constant PR25   = 0x72E4327F592E9Cb09d5730a55D1D68De144aF53C;

    event PoweredUp(address indexed user, address indexed nftContract, uint wethSpent, uint lpCreated);

    /// @notice Spend WETH to create BTN/PR25 LP and send it to an NFT contract
    function powerUp(address nftContract, uint wethAmount) external {
        require(wethAmount > 0, "Zero amount");
        IERC20(WETH).transferFrom(msg.sender, address(this), wethAmount);

        uint half = wethAmount / 2;
        _swapWethTo(BTN, half);
        _swapWethTo(PR25, wethAmount - half);

        uint lpCreated = _addLpAndSend(nftContract);

        _refund(WETH);
        _refund(BTN);
        _refund(PR25);

        emit PoweredUp(msg.sender, nftContract, wethAmount, lpCreated);
    }

    function _swapWethTo(address tokenOut, uint amount) internal {
        IERC20(WETH).approve(address(router), amount);
        if (tokenOut == PR25) {
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = PR25;
            router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp + 300);
        } else {
            address[] memory path = new address[](3);
            path[0] = WETH;
            path[1] = PR25;
            path[2] = tokenOut;
            router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp + 300);
        }
    }

    function _addLpAndSend(address to) internal returns (uint liquidity) {
        uint balBtn  = IERC20(BTN).balanceOf(address(this));
        uint balPr25 = IERC20(PR25).balanceOf(address(this));
        IERC20(BTN).approve(address(router), balBtn);
        IERC20(PR25).approve(address(router), balPr25);
        (,, liquidity) = router.addLiquidity(BTN, PR25, balBtn, balPr25, 0, 0, to, block.timestamp + 300);
    }

    function _refund(address token) internal {
        uint bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).transfer(msg.sender, bal);
    }
}
