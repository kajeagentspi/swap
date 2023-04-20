// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { console2 } from "forge-std/console2.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _receiver, bytes calldata _data) external;
}

interface SolidlyPair {
    function getAmountOut(uint256 _amountIn, address _tokenIn) external view returns (uint256);
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _receiver, bytes calldata _data) external;
}

interface GMXVault {
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
    function coins(uint256 i) external view returns (address);
}

interface IAsset {
// solhint-disable-previous-line no-empty-blocks
}

interface Balancer {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    )
        external
        payable
        returns (uint256);
}

contract Swapper {
    event Received(address sender, uint256 amount);

    address public owner;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public withdrawer;

    uint256 private constant UNISWAP = 1;
    uint256 private constant SOLIDLY = 2;
    uint256 private constant GMX = 3;
    uint256 private constant CURVE = 4;
    uint256 private constant BALANCER = 5;

    constructor() {
        owner = msg.sender;
        whitelist[msg.sender] = true;
        withdrawer[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NGMI");
        _;
    }

    modifier onlyWithdrawer() {
        require(withdrawer[msg.sender] == true, "NGMI");
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

    function revoke(address _token, address _spender) public onlyOwner {
        IERC20(_token).approve(_spender, 0);
    }

    function approveMulti(address[] calldata _tokens, address _spender) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i = unsafe_inc(i)) {
            IERC20(_tokens[i]).approve(
                _spender,
                115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
            );
        }
    }

    function revokeMulti(address[] calldata _tokens, address _spender) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i = unsafe_inc(i)) {
            IERC20(_tokens[i]).approve(_spender, 0);
        }
    }

    function addKeeper(address[] calldata _keepers) public onlyOwner {
        for (uint256 i = 0; i < _keepers.length; i = unsafe_inc(i)) {
            whitelist[_keepers[i]] = true;
        }
    }

    function removeKeeper(address[] calldata _keepers) public onlyOwner {
        for (uint256 i = 0; i < _keepers.length; i = unsafe_inc(i)) {
            whitelist[_keepers[i]] = false;
        }
    }

    function addWithdrawer(address _withdrawer) public onlyOwner {
        withdrawer[_withdrawer] = true;
    }

    function removeWithdrawer(address _withdrawer) public onlyOwner {
        withdrawer[_withdrawer] = false;
    }

    function withdrawToken(address _token, uint256 _amount) public onlyWithdrawer {
        uint256 maxBalance = IERC20(_token).balanceOf(address(this));
        if (_amount > maxBalance) {
            _amount = maxBalance;
        }
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function withMe() public onlyWhitelisted {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    function transfer(address _token, uint256 _amount, address _receiver) public onlyWhitelisted {
        IERC20(_token).transfer(_receiver, _amount);
    }

    // SWAP MULTIPLE
    function swap(bytes memory _routeData) public onlyWhitelisted {
        // uniswap 114=32+20+20+20+20+2
        // solidly 112=32+20+20+20+20
        // gmx      80=20+20+20+20
        // curve    54=32+20+1+1 use uint8 for indexes
        // balancer 92=20+32+20+20
        // _swapData routeLength, dexType0, dexType1..., amountIn, minAmountOut, ,swapData0, swapData1...
        uint8 routeLength;
        uint256[5] memory dexTypes;
        assembly {
            routeLength := mload(add(add(_routeData, 0x1), 0))
        }
        for (uint256 i = 1; i < routeLength + 1; i = unsafe_inc(i)) {
            uint8 tempSize;
            assembly {
                tempSize := mload(add(add(_routeData, 0x1), i))
            }
            dexTypes[i - 1] = tempSize;
        }
        uint256 currentIndex = 1 + routeLength;
        uint256 amountIn;
        uint256 minAmountOut;
        assembly {
            amountIn := mload(add(add(_routeData, 0x20), currentIndex))
            minAmountOut := mload(add(add(_routeData, 0x20), add(currentIndex, 32)))
        }
        currentIndex += 64; //increment index after reading amountIn

        uint256 balanceBefore;
        address receiver;
        address lastToken;
        for (uint256 i = 0; i < routeLength; i = unsafe_inc(i)) {
            // When last route, next is curve or next is balancer
            if (i + 1 == routeLength || dexTypes[i] == CURVE || dexTypes[i + 1] == CURVE || dexTypes[i + 1] == BALANCER)
            {
                receiver = address(this);
            } else {
                uint256 toAddressIndex = currentIndex + 60;
                assembly {
                    receiver := div(mload(add(add(_routeData, 0x20), toAddressIndex)), 0x1000000000000000000000000)
                }
            }
            if (dexTypes[i] == UNISWAP || dexTypes[i] == SOLIDLY || dexTypes[i] == GMX) {
                address pair; //vault address in the case of balancer or gmx
                address tokenIn;
                address tokenOut;
                assembly {
                    pair := div(mload(add(add(_routeData, 0x20), currentIndex)), 0x1000000000000000000000000)
                    tokenIn :=
                        div(mload(add(add(_routeData, 0x20), add(currentIndex, 20))), 0x1000000000000000000000000)
                    tokenOut :=
                        div(mload(add(add(_routeData, 0x20), add(currentIndex, 40))), 0x1000000000000000000000000)
                }
                currentIndex += 60;
                if (i == 0 || dexTypes[i - 1] == CURVE) {
                    IERC20(tokenIn).transfer(pair, amountIn);
                }
                if (i + 1 == routeLength) {
                    lastToken = tokenOut;
                    balanceBefore = IERC20(tokenOut).balanceOf(address(this));
                }
                if (dexTypes[i] == UNISWAP) {
                    uint16 _swapFee;
                    assembly {
                        _swapFee := mload(add(add(_routeData, 0x2), currentIndex))
                    }
                    uint256 swapFee = _swapFee;
                    currentIndex += 2;
                    amountIn = _uniswap(amountIn, pair, tokenIn, tokenOut, receiver, swapFee);
                } else if (dexTypes[i] == SOLIDLY) {
                    amountIn = _solidlyswap(amountIn, pair, tokenIn, tokenOut, receiver);
                } else if (dexTypes[i] == GMX) {
                    amountIn = _gmxswap(pair, tokenIn, tokenOut, receiver);
                }
            } else if (dexTypes[i] == CURVE) {
                address pair; //vault address in the case of balancer or gmx
                uint8 tokenInIndex;
                uint8 tokenOutIndex;
                assembly {
                    pair := div(mload(add(add(_routeData, 0x20), currentIndex)), 0x1000000000000000000000000)
                    tokenInIndex := mload(add(add(_routeData, 0x1), add(currentIndex, 20)))
                    tokenOutIndex := mload(add(add(_routeData, 0x1), add(currentIndex, 21)))
                }
                currentIndex += 22;
                if (i + 1 == routeLength) {
                    lastToken = CurveFi(pair).coins(tokenOutIndex);
                    balanceBefore = IERC20(lastToken).balanceOf(address(this));
                }
                amountIn = _curveswap(amountIn, pair, int128(uint128(tokenInIndex)), int128(uint128(tokenOutIndex)));
            } else if (dexTypes[i] == BALANCER) {
                (address pair, bytes32 poolId, address tokenIn, address tokenOut) =
                    parseBalancer(_routeData, currentIndex);
                currentIndex += 92;
                if (i + 1 == routeLength) {
                    lastToken = tokenOut;
                    balanceBefore = IERC20(lastToken).balanceOf(address(this));
                }
                amountIn = _balancerswap(amountIn, pair, poolId, tokenIn, tokenOut, receiver);
            }
        }
        uint256 balanceAfter = IERC20(lastToken).balanceOf(address(this));
        console2.log(balanceBefore, balanceAfter, balanceAfter - balanceBefore, minAmountOut);
        require(balanceAfter - balanceBefore >= minAmountOut, "Not Enough");
    }

    function parseBalancer(
        bytes memory _routeData,
        uint256 _currentIndex
    )
        internal
        pure
        returns (address pair, bytes32 poolId, address tokenIn, address tokenOut)
    {
        //vault address in the case of balancer or gmx
        assembly {
            pair := div(mload(add(add(_routeData, 0x20), _currentIndex)), 0x1000000000000000000000000)
            poolId := mload(add(add(_routeData, 0x20), add(_currentIndex, 20)))
            tokenIn := div(mload(add(add(_routeData, 0x20), add(_currentIndex, 52))), 0x1000000000000000000000000)
            tokenOut := div(mload(add(add(_routeData, 0x20), add(_currentIndex, 72))), 0x1000000000000000000000000)
        }
    }

    // SWAPS
    function _uniswap(
        uint256 _amountIn,
        address _pair,
        address _tokenIn,
        address _tokenOut,
        address _receiver,
        uint256 _swapFee
    )
        internal
        returns (uint256)
    {
        (uint256 amountOut, bool reversed) = _getAmountOutUniswap(_amountIn, _pair, _tokenIn, _tokenOut, _swapFee);
        (uint256 amount0Out, uint256 amount1Out) = reversed ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IUniswapV2Pair(_pair).swap(amount0Out, amount1Out, _receiver, new bytes(0));
        return amountOut;
    }

    function _solidlyswap(
        uint256 _amountIn,
        address _pair,
        address _tokenIn,
        address _tokenOut,
        address _receiver
    )
        internal
        returns (uint256 amountOut)
    {
        amountOut = SolidlyPair(_pair).getAmountOut(_amountIn, _tokenIn);
        (address token0,) = _sortTokens(_tokenIn, _tokenOut);
        (uint256 amount0Out, uint256 amount1Out) =
            token0 == _tokenIn ? (uint256(0), amountOut) : (amountOut, uint256(0));
        SolidlyPair(_pair).swap(amount0Out, amount1Out, _receiver, new bytes(0));
        return amountOut;
    }

    function _gmxswap(
        address _vaultAddress,
        address _tokenIn,
        address _tokenOut,
        address _receiver
    )
        internal
        returns (uint256)
    {
        return GMXVault(_vaultAddress).swap(_tokenIn, _tokenOut, _receiver);
    }

    function _curveswap(
        uint256 _amountIn,
        address _pair,
        int128 _tokenInIndex,
        int128 _tokenOutIndex
    )
        internal
        returns (uint256 amountOut)
    {
        amountOut = CurveFi(_pair).get_dy(_tokenInIndex, _tokenOutIndex, _amountIn);
        CurveFi(_pair).exchange(_tokenInIndex, _tokenOutIndex, _amountIn, 0);
        return amountOut;
    }

    function _balancerswap(
        uint256 _amountIn,
        address _balancerVault,
        bytes32 _poolId,
        address _tokenIn,
        address _tokenOut,
        address _receiver
    )
        internal
        returns (uint256)
    {
        Balancer.FundManagement memory fm = Balancer.FundManagement(address(this), false, payable(_receiver), false);
        Balancer.SingleSwap memory ss =
            Balancer.SingleSwap(_poolId, Balancer.SwapKind.GIVEN_IN, IAsset(_tokenIn), IAsset(_tokenOut), _amountIn, "");
        return Balancer(_balancerVault).swap(ss, fm, 0, block.timestamp);
    }

    // HELPERS
    function _getAmountOutUniswap(
        uint256 _amountIn,
        address _pair,
        address _tokenIn,
        address _tokenOut,
        uint256 _swapFee
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

    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    // GOD CALLS
    struct Call {
        address target;
        bytes callData;
    }

    function doFarmLabor(Call[] memory _calls)
        public
        onlyOwner
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        returnData = new bytes[](_calls.length);
        for (uint256 i = 0; i < _calls.length; i++) {
            (bool success, bytes memory ret) = _calls[i].target.call(_calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
}
