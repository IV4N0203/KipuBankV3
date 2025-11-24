// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";

contract DeployKipuBankV3 is Script {
    // Variables de configuración 
    // USDC en Sepolia (Token de prueba común)
    address constant SEPOLIA_USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    // Uniswap V2 Router en Sepolia
    address constant SEPOLIA_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    // Configuración del Banco
    uint256 constant BANK_CAP = 100_000 * 1e6; // 100,000 USDC (6 decimales)
    uint256 constant WITHDRAWAL_LIMIT = 10_000 * 1e6; // 10,000 USDC

    function run() external returns (KipuBankV3) {
        // Inicio de la transacción de despliegue
        vm.startBroadcast();

        // Despliegue del contrato pasando los argumentos del constructor
        // Orden: _bankCapUSDC, _withdrawalThresholdUSDC, _uniswapRouter, _usdc
        KipuBankV3 kipuBank = new KipuBankV3(
            BANK_CAP,
            WITHDRAWAL_LIMIT,
            SEPOLIA_ROUTER,
            SEPOLIA_USDC
        );

        vm.stopBroadcast();

        // Logs para verificar en consola
        console.log("KipuBankV3 desplegado en:", address(kipuBank));
        console.log("Owner del contrato:", kipuBank.owner());
        
        return kipuBank;
    }
}