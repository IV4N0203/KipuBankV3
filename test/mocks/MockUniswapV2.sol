// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Mock simple de Uniswap Router y Factory para pruebas unitarias
 */
contract MockUniswapV2Router {
    address public factory;
    address public WETH;

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    // Simula la consulta de precios. Devuelve siempre 1:1 para simplificar tests
    function getAmountsOut(uint256 amountIn, address[] calldata path) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        for (uint i = 0; i < path.length; i++) {
            amounts[i] = amountIn; // 1 Token = 1 USDC en este mundo simulado
        }
        return amounts;
    }

    // Simula el swap de Tokens a Tokens
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        // El mock simplemente "regala" los tokens de salida al contrato
        // En un test real, el MockERC20 debe tener tokens minteados en este router
        address tokenOut = path[path.length - 1];
        // Simulamos que el router envía los tokens comprados
        // (Nota: Debes mintear tokens al Router en el setup del test)
        IERC20(tokenOut).transfer(to, amountIn); 
        
        return getAmountsOut(amountIn, path);
    }

    // Simula swap de ETH a Tokens
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        address tokenOut = path[path.length - 1];
        IERC20(tokenOut).transfer(to, msg.value);
        return getAmountsOut(msg.value, path);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }
}