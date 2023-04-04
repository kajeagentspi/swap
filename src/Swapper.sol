// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes calldata _data) external;
}

interface SolidlyPair {
    function getAmountOut(uint256 _amountIn, address _tokenIn) external view returns (uint256);
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes calldata _data) external;
}

interface MummyVault {
    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);
}

interface CurveFi {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function get_dx_underlying(int128 i, int128 j, uint256 dy) external view returns (uint256);
    function get_dy_underlying(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_dx(int128 i, int128 j, uint256 dy) external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
}

contract Swapper {
    event Received(address sender, uint256 amount);

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

    function approve(address _token, address _spender) public onlyOwner {
        IERC20(_token).approve(
            _spender,
            115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
        );
    }

    function approveMulti(address[] calldata _tokens, address _spender) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i = unsafe_inc(i)) {
            IERC20(_tokens[i]).approve(
                _spender,
                115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
            );
        }
    }

    function addKeeper(address[] calldata keepers) public onlyOwner {
        for (uint256 i = 0; i < keepers.length; i = unsafe_inc(i)) {
            whitelist[keepers[i]] = true;
        }
    }

    function removeKeeper(address[] calldata keepers) public onlyOwner {
        for (uint256 i = 0; i < keepers.length; i = unsafe_inc(i)) {
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

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    function transfer(address token, uint256 amount, address to) public onlyWhitelisted {
        IERC20(token).transfer(to, amount);
    }

    // SWAPS
    function _uniswap(
        uint256 _amountIn,
        uint16 _swapFee,
        address _pair,
        address _tokenIn,
        address _tokenOut,
        address _to
    )
        public
        onlyWhitelisted
        returns (uint256)
    {
        (uint256 amountOut, bool reversed) = _getAmountOutUniswap(_amountIn, _swapFee, _pair, _tokenIn, _tokenOut);
        (uint256 amount0Out, uint256 amount1Out) = reversed ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IUniswapV2Pair(_pair).swap(amount0Out, amount1Out, _to, new bytes(0));
        return amountOut;
    }

    function _solidlyswap(
        uint256 _amountIn,
        address _pair,
        address _tokenIn,
        address _tokenOut,
        address _to
    )
        public
        onlyWhitelisted
        returns (uint256 amountOut)
    {
        amountOut = SolidlyPair(_pair).getAmountOut(_amountIn, _tokenIn);
        (address token0,) = _sortTokens(_tokenIn, _tokenOut);
        (uint256 amount0Out, uint256 amount1Out) =
            token0 == _tokenIn ? (uint256(0), amountOut) : (amountOut, uint256(0));
        SolidlyPair(_pair).swap(amount0Out, amount1Out, _to, new bytes(0));
        return amountOut;
    }

    function _mummyswap(
        address _vaultAddress,
        address _tokenIn,
        address _tokenOut,
        address _to
    )
        public
        onlyWhitelisted
        returns (uint256)
    {
        return MummyVault(_vaultAddress).swap(_tokenIn, _tokenOut, _to);
    }

    function _curveswap(
        uint256 _amountIn,
        address _pair,
        int128 _tokenInIndex,
        int128 _tokenOutIndex
    )
        public
        onlyWhitelisted
        returns (uint256 amountOut)
    {
        amountOut = CurveFi(_pair).get_dy(_tokenInIndex,_tokenOutIndex,_amountIn);
        CurveFi(_pair).exchange(_tokenInIndex, _tokenOutIndex, _amountIn, 0);
        return amountOut;
    }

    // HELPERS
    function _getAmountOutUniswap(
        uint256 _amountIn,
        uint16 _swapFee,
        address _pair,
        address _tokenIn,
        address _tokenOut
    )
        internal
        view
        returns (uint256 amountOut, bool reversed)
    {
        (address token0,) = _sortTokens(_tokenIn, _tokenOut);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_pair).getReserves();
        reversed = _tokenIn == token0;
        (uint256 reserveIn, uint256 reserveOut) = reversed ? (reserve0, reserve1) : (reserve1, reserve0);
        assembly {
            let amountInWithFee := mul(_amountIn, _swapFee)
            let numerator := mul(amountInWithFee, reserveOut)
            let denominator := mul(reserveIn, 10000)
            denominator := add(denominator, amountInWithFee)
            amountOut := div(mul(amountInWithFee, reserveOut), denominator)
        }
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // GOD CALLS
    struct Call {
        address target;
        bytes callData;
    }

    function doFarmLabor(Call[] memory calls)
        public
        onlyOwner
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
}
