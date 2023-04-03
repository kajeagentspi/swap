// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function sync() external;
}

interface MummyVault {
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
}

contract Swapper {
    event Received(address sender, uint amount);

    address public owner;
    mapping(address => bool) public whitelist;
    
    constructor() {
        owner = msg.sender;
        whitelist[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NGMI");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] == true, "NGMI");
        _;
    }

    function approve(address token, address spender) public onlyOwner {
        IERC20(token).approve(spender, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
    }

    function approveMulti(address[] calldata tokens, address spender) public onlyOwner {
        for (uint i = 0; i < tokens.length; i = unsafe_inc(i)) {
            IERC20(tokens[i]).approve(spender, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        }
    }

    function addKeeper(address[] calldata keepers) public onlyOwner{
        for (uint i = 0; i < keepers.length; i = unsafe_inc(i)) {
            whitelist[keepers[i]] = true;
        }
    }

    function removeKeeper(address[] calldata keepers) public onlyOwner {
        for (uint i = 0; i < keepers.length; i = unsafe_inc(i)) {
            whitelist[keepers[i]] = false;
        }
    }

    function withdrawToken(address token) public onlyWhitelisted {
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }

    function withMe() public onlyWhitelisted {
        address payable nushi = payable(owner);
        nushi.transfer(address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }
    
    function getOwner() external view returns (address) {
        return owner;
    }

    function unsafe_inc(uint x) private pure returns (uint) {
        unchecked { return x + 1; }
    }

    function transfer(address token, uint amount, address to)public onlyWhitelisted{
        IERC20(token).transfer(to, amount);
    }

    function swapArbUni(bytes calldata data) public onlyWhitelisted {
        (uint256 amountIn, uint16[] memory fees, address[] memory pairs, address[] memory tokens) = abi.decode(data, (uint256,uint16[],address[],address[]));
        uint startingBalance = IERC20(tokens[0]).balanceOf(address(this));
        if(amountIn > startingBalance){
            amountIn = startingBalance;
        }
        if(amountIn == 0){
            return;
        }
        uint[] memory amountsOut = new uint[](pairs.length);
        for (uint i; i < pairs.length; i = unsafe_inc(i)) {
            if (i == 0) {
                amountsOut[i] = _getAmountOutUniswapRO(amountIn, fees[i], pairs[i], tokens[i], tokens[i+1]);
            } else {
                amountsOut[i] = _getAmountOutUniswapRO(amountsOut[i-1], fees[i], pairs[i], tokens[i], tokens[i+1]);
            }
        }
        if(amountIn > amountsOut[pairs.length-1]){
            return;
        }
        IERC20(tokens[0]).transfer(pairs[0], amountIn);
        for (uint i; i < pairs.length; i = unsafe_inc(i)) {
            if (i == pairs.length - 1) { //if last pair
                _uniswap(amountsOut[i], pairs[i], tokens[i], tokens[i+1], address(this));
            } else { //if can do flash swap
                _uniswap(amountsOut[i], pairs[i], tokens[i], tokens[i+1], pairs[i+1]);
            }
        }
        require(startingBalance <= IERC20(tokens[0]).balanceOf(address(this)), "Arb failed 1");
    }

    function mummyswap(address vaultAddress, address tokenIn, address tokenOut, address to) public onlyWhitelisted {
        MummyVault(vaultAddress).swap(tokenIn,tokenOut,to);
    }

    function _uniswap(uint amountOut, address pair, address tokenIn, address tokenOut, address to) public onlyWhitelisted {
        (address token0,) = _sortTokens(tokenIn, tokenOut);
        bool isNotFlipped = tokenIn == token0;
        (uint amount0Out, uint amount1Out) = isNotFlipped ? (uint(0), amountOut) : (amountOut, uint(0));
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
    }

    function _getAmountOutUniswapRO(uint amountInput, uint16 fee, address pair, address tokenIn, address tokenOut) public view returns (uint amountOutput) {
        (address token0,) = _sortTokens(tokenIn, tokenOut);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        (uint reserveInput, uint reserveOutput) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOutput = _getAmountOutUniswap(amountInput, reserveInput, reserveOutput, fee);
    }

    function _getAmountOutUniswap(uint amountIn, uint reserveIn, uint reserveOut, uint swapFee) internal pure returns (uint amountOut) {
        assembly {
            let amountInWithFee := mul(amountIn, swapFee)
            let numerator := mul(amountInWithFee,reserveOut)
            let denominator := mul(reserveIn,10000)
            denominator := add(denominator, amountInWithFee)
            amountOut := div(numerator, denominator)
        }
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
