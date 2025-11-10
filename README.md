# KipuBankV3 🏦🔄 - IVAN ALARCON

**Banco DeFi Avanzado con Integración de Uniswap V2**

Una evolución de KipuBankV2 que acepta **cualquier token con liquidez en Uniswap V2**, realiza **swaps automáticos a USDC** y gestiona toda la contabilidad en un único activo base, simplificando la experiencia del usuario mientras mantiene la seguridad y transparencia.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Uniswap V2](https://img.shields.io/badge/Uniswap-V2-FF007A)](https://uniswap.org/)


---

## 🎯 Resumen

KipuBankV3 representa un salto hacia una aplicación DeFi real y usable. **El problema central que resuelve**: los usuarios tienen múltiples tokens pero quieren simplicidad en su gestión.

### KipuBankV3 mejoras visibles:

1. **Acepta CUALQUIER token** con liquidez en Uniswap V2 (ETH, WBTC, DAI, LINK, etc.)
2. **Swapea automáticamente** a USDC usando el mejor path disponible
3. **Gestiona TODO en USDC** - un único balance, sin complejidad multi-token
4. **Respeta límites USD** - el bank cap se valida post-swap
5. **Mantiene funcionalidad V2** - control de acceso, estadísticas, eventos

### Caso de Uso

```
Usuario tiene: 1 ETH + 0.5 WBTC + 100 DAI + 50 LINK
Usuario quiere: Depositar todo en un lugar seguro

❌ KipuBankV2: Necesita oráculos para cada token, conversión manual, gestión compleja
✅ KipuBankV3: Deposita cada token -> automáticamente convertido a USDC -> balance único
```

---

## 🚀 Mejoras Clave V2 vs V3

| Aspecto | KipuBankV2 | KipuBankV3 |
|---------|------------|------------|
| **Tokens soportados** | Limitados con oráculos específicos | Cualquiera con liquidez en Uniswap V2 |
| **Conversión de precios** | Chainlink oráculos | Swaps reales de mercado |
| **Contabilidad** | Multi-token complejo | USDC único (simplificado) |
| **Depósitos** | Tokens específicos + Chainlink | ETH + cualquier ERC20 |
| **Retiros** | Por token individual | Siempre en USDC |
| **Gestión de liquidez** | No aplica | Verifica pools Uniswap |
| **Slippage** | No aplica | Protección 0.5% máximo |
| **Path optimization** | No aplica | Directo o vía WETH |
| **Límite del banco** | En USD teórico | En USDC real post-swap |

### Mejoras Implementadas Detalladas

#### 1. **Integración Completa con Uniswap V2**

```solidity
// Interfaces utilizadas
IUniswapV2Router02 - Para ejecutar swaps
IUniswapV2Factory - Para validar pools de liquidez

// Funcionalidades
- swapExactETHForTokens: ETH → USDC
- swapExactTokensForTokens: ERC20 → USDC
- getAmountsOut: Estimación de output
- getPair: Validación de liquidez
```

**Beneficio**: Precios reales de mercado en lugar de oráculos centralizados.

#### 2. **Sistema de Swaps Automáticos**

```solidity
function depositToken(address _token, uint256 _amount) external {
    // 1. Transferir token al contrato
    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    
    // 2. Si no es USDC, swapear automáticamente
    if (tokenInfo.requiresSwap) {
        usdcReceived = _swapTokenToUSDC(_token, _amount);
    }
    
    // 3. Acreditar USDC al balance del usuario
    s_balances[msg.sender] += usdcReceived;
}
```

**Proceso interno de swap**:
1. Aprobar router de Uniswap
2. Determinar path óptimo (directo vs vía WETH)
3. Calcular mínimo output con slippage
4. Ejecutar swap
5. Emitir evento con detalles

#### 3. **Optimización de Path**

El contrato inteligentemente decide la mejor ruta para el swap:

```solidity
function _getOptimalPath(address _tokenIn, address _tokenOut) 
    returns (address[] memory path) 
{
    // Opción 1: Par directo (más eficiente)
    if (existe pool Token/USDC) {
        path = [Token, USDC]  // 1 hop, menos gas
    }
    // Opción 2: Vía WETH (mayor liquidez)
    else {
        path = [Token, WETH, USDC]  // 2 hops, más seguro
    }
}
```

**Ejemplo real**:
- **DAI → USDC**: Par directo (1 hop)
- **LINK → USDC**: LINK → WETH → USDC (2 hops, mayor liquidez)

#### 4. **Gestión Simplificada de Balances**

**V2**: Mapeo anidado complejo
```solidity
mapping(address user => mapping(address token => uint256)) balances;
// User1: {ETH: 1.5, DAI: 100, USDC: 50}
// Complejidad: O(n) tokens por usuario
```

**V3**: Balance único en USDC
```solidity
mapping(address user => uint256 usdcBalance) balances;
// User1: {USDC: 3847.23}
// Complejidad: O(1) - constante
```

**Ventajas**:
- ✅ Consultas más rápidas
- ✅ Menos gas en operaciones
- ✅ UX simplificada para usuarios
- ✅ Contabilidad unificada

#### 5. **Protección contra Slippage**

```solidity
uint256 constant MAX_SLIPPAGE_BP = 50; // 0.5%

// Cálculo de mínimo aceptable
uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
uint256 minAmountOut = (amountsOut[last] * 9950) / 10000; // 99.5% del estimado

// Swap con protección
router.swapExactTokensForTokens(
    amountIn,
    minAmountOut,  // ❌ Revierte si output < minimo
    path,
    address(this),
    deadline
);
```

**Previene**:
- Front-running attacks
- Sandwichattacks
- Manipulación de precio temporal
- Pérdidas por volatilidad extrema

#### 6. **Validación de Liquidez**

Antes de agregar un token, el contrato verifica que exista liquidez real:

```solidity
function addSupportedToken(address _token, bool _requiresSwap) external onlyOwner {
    if (_requiresSwap) {
        _validateLiquidityPool(_token);
    }
    // ...
}

function _validateLiquidityPool(address _token) private view {
    address directPair = factory.getPair(_token, USDC);
    if (directPair == address(0)) {
        address wethPair = factory.getPair(_token, WETH);
        require(wethPair != address(0), "No liquidity");
    }
}
```

**Beneficio**: Previene agregar tokens sin mercado, evitando swaps fallidos.

---

## 🏗️ Arquitectura Técnica

### Diagrama de Flujo de Depósito

```
Usuario → depositToken(DAI, 100)
    │
    ├─► ✓ Verificar token soportado
    ├─► ✓ Transferir DAI al contrato
    │
    ├─► ¿Es USDC?
    │   ├─► SÍ → Acreditar directo
    │   └─► NO ↓
    │
    ├─► Determinar path óptimo
    │   ├─► DAI/USDC existe? → [DAI, USDC]
    │   └─► No existe? → [DAI, WETH, USDC]
    │
    ├─► Aprobar Uniswap Router
    ├─► Obtener amountsOut estimado
    ├─► Calcular minAmountOut (slippage)
    │
    ├─► Ejecutar Swap en Uniswap V2
    │   └─► Router.swapExactTokensForTokens()
    │
    ├─► Recibir USDC
    ├─► ✓ Verificar bank cap
    │
    └─► ✓ Actualizar estado
        ├─► s_balances[user] += usdcReceived
        ├─► s_totalUSDCBalance += usdcReceived
        ├─► s_tokenStats[DAI].totalDeposited += 100
        └─► Emit DepositMade event
```

### Componentes del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    KipuBankV3                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Access Control (Ownable)                        │   │
│  │  Reentrancy Protection (ReentrancyGuard)         │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │ Token Manager│  │ Swap Engine  │  │ Balance Mgr │  │
│  │ - Add Token  │  │ - ETH→USDC  │  │ - Deposits  │  │
│  │ - Remove     │  │ - ERC20→USDC│  │ - Withdraws │  │
│  │ - Validate   │  │ - Path Opt  │  │ - Stats     │  │
│  └──────────────┘  └──────────────┘  └─────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │          User Interface (Public)                 │   │
│  │  depositETH() | depositToken() | withdrawUSDC()  │   │
│  │  getUserBalance() | estimateDepositOutput()      │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │ Uniswap  │        │   ERC20  │        │   USDC   │
   │ V2 Router│        │  Tokens  │        │  Balance │
   └──────────┘        └──────────┘        └──────────┘
```

### Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|-----------|---------|
| **Lenguaje** | Solidity | 0.8.26 |
| **Framework** | Foundry | Latest |
| **DEX** | Uniswap V2 | Core + Periphery |
| **Seguridad** | OpenZeppelin | ^5.0.0 |
| **Testing** | Forge | Foundry |
| **Despliegue** | Forge Script | Foundry |

---

## 🛠️ Instalación y Configuración

### Prerrequisitos

```bash
# Foundry (recomendado)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
cast --version
```

### Clonar y Configurar

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/KipuBankV3.git
cd KipuBankV3

# Instalar dependencias
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v2-core
forge install Uniswap/v2-periphery

# Compilar
forge build
```

### Estructura del Proyecto

```
KipuBankV3/
├── src/
│   └── KipuBankV3.sol              # Contrato principal
├── script/
│   ├── DeployKipuBankV3.s.sol      # Script de despliegue
│   └── InteractKipuBankV3.s.sol    # Scripts de interacción
├── test/
│   ├── KipuBankV3.t.sol            # Tests unitarios
│   ├── KipuBankV3Integration.t.sol # Tests de integración
│   └── mocks/
│       ├── MockERC20.sol
│       └── MockUniswapV2.sol
├── lib/                             # Dependencias
│   ├── openzeppelin-contracts/
│   ├── v2-core/
│   └── v2-periphery/
├── foundry.toml                     # Configuración de Foundry
├── .env.example                     # Template de variables
└── README.md                        # Este archivo
```

### Variables de Entorno

Crear archivo `.env`:

```bash
# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY

# Private Key
PRIVATE_KEY=your_private_key_here

# Etherscan API
ETHERSCAN_API_KEY=your_api_key

# Direcciones de Contratos (Sepolia)
UNISWAP_V2_ROUTER=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
USDC_ADDRESS=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8

# Parámetros de Despliegue
BANK_CAP_USDC=100000000000  # $100,000 (6 decimals)
WITHDRAWAL_THRESHOLD=10000000000  # $10,000 (6 decimals)
```

---

## 🚀 Despliegue

### Paso 1: Compilar

```bash
forge build --sizes
```

### Paso 2: Tests Pre-Despliegue

```bash
# Tests unitarios
forge test -vv

# Tests con coverage
forge coverage

# Tests de gas
forge test --gas-report
```

### Paso 3: Desplegar en Sepolia

```bash
# Despliegue básico
forge script script/DeployKipuBankV3.s.sol:DeployKipuBankV3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv

# El script automáticamente:
# ✓ Despliega el contrato
# ✓ Configura USDC como token base
# ✓ Verifica en Etherscan
# ✓ Guarda dirección en deployments.json
```

###Paso 4: Configuración Post-Despliegue

```bash
# Agregar soporte para ETH
cast send $CONTRACT_ADDRESS "addETHSupport()" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Agregar soporte para DAI
cast send $CONTRACT_ADDRESS \
    "addSupportedToken(address,bool)" \
    0x68194a729C2450ad26072b3D33ADaCbcef39D574 \ # DAI Sepolia
    true \ # requiresSwap = true
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY

# Agregar soporte para LINK
cast send $CONTRACT_ADDRESS \
    "addSupportedToken(address,bool)" \
    0x779877A7B0D9E8603169DdbD7836e478b4624789 \ # LINK Sepolia
    true \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
```

### Parámetros de Despliegue Recomendados

| Red | Bank Cap | Withdrawal Threshold | Router | USDC |
|-----|----------|---------------------|--------|------|
| **Sepolia** | $100,000 | $10,000 | 0x7a250d5630... | 0x94a9D9AC8a22... |
| **Mainnet** | $1,000,000 | $50,000 | 0x7a250d5630... | 0xA0b86991c6218... |

---

## 💻 Interacción con el Contrato

### Usando Cast (Foundry)

#### 1. Depositar ETH

```bash
# Depositar 0.1 ETH
cast send $CONTRACT_ADDRESS "depositETH()" \
    --value 0.1ether \
    --private-key $PRIVATE_KEY \
    --rpc-url $SEPOLIA_RPC_URL

# El contrato automáticamente:
# 1. Recibe 0.1 ETH
# 2. Swapea a USDC via Uniswap V2
# 3. Acredita USDC al balance del usuario
```

#### 2. Depositar Tokens ERC20

```bash
# Primero: Aprobar el contrato para gastar tus tokens
cast send $TOKEN_ADDRESS "approve(address,uint256)" \
    $CONTRACT_ADDRESS \
    1000000000000000000000 \ # 1000 tokens (18 decimals)
    --private-key $PRIVATE_KEY \
    --rpc-url $SEPOLIA_RPC_URL

# Segundo: Depositar tokens
cast send $CONTRACT_ADDRESS \
    "depositToken(address,uint256)" \
    $TOKEN_ADDRESS \
    1000000000000000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $SEPOLIA_RPC_URL
```

#### 3. Consultar Balance

```bash
# Balance en USDC del usuario
cast call $CONTRACT_ADDRESS \
    "getUserBalance(address)" \
    $USER_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL

# Resultado: 2456789012 (2,456.789012 USDC)
```

#### 4. Estimar Output de Depósito

```bash
# Estimar cuánto USDC recibirás por 1 ETH
cast call $CONTRACT_ADDRESS \
    "estimateDepositOutput(address,uint256)" \
    0x0000000000000000000000000000000000000000 \ # address(0) = ETH
    1000000000000000000 \ # 1 ETH
    --rpc-url $SEPOLIA_RPC_URL

# Resultado: 1990000000 (1,990 USDC después de slippage 0.5%)
```

#### 5. Retirar USDC

```bash
# Retirar 500 USDC
cast send $CONTRACT_ADDRESS \
    "withdrawUSDC(uint256)" \
    500000000 \ # 500 USDC (6 decimals)
    --private-key $PRIVATE_KEY \
    --rpc-url $SEPOLIA_RPC_URL
```

#### 6. Estadísticas del Banco

```bash
# Obtener stats generales
cast call $CONTRACT_ADDRESS "getBankStats()" \
    --rpc-url $SEPOLIA_RPC_URL

# Retorna: (totalUSDC, remainingCap, tokensCount, deposits, withdrawals)
```

### Usando Ethers.js

```javascript
const { ethers } = require("ethers");

// Setup
const provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

// 1. Depositar ETH
async function depositETH() {
    const tx = await contract.depositETH({ 
        value: ethers.utils.parseEther("0.1") 
    });
    const receipt = await tx.wait();
    
    // Obtener evento DepositMade
    const event = receipt.events.find(e => e.event === "DepositMade");
    console.log("USDC received:", ethers.utils.formatUnits(event.args.usdcReceived, 6));
}

// 2. Depositar ERC20
async function depositToken(tokenAddress, amount) {
    // Aprobar primero
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, wallet);
    const approveTx = await token.approve(CONTRACT_ADDRESS, amount);
    await approveTx.wait();
    
    // Depositar
    const depositTx = await contract.depositToken(tokenAddress, amount);
    const receipt = await depositTx.wait();
    
    console.log("Deposit successful!");
}

// 3. Consultar balance
async function getBalance(userAddress) {
    const balance = await contract.getUserBalance(userAddress);
    console.log("Balance:", ethers.utils.formatUnits(balance, 6), "USDC");
}

// 4. Estimar output
async function estimateDeposit(tokenAddress, amount) {
    const estimated = await contract.estimateDepositOutput(tokenAddress, amount);
    console.log("Expected USDC:", ethers.utils.formatUnits(estimated, 6));
}

// 5. Retirar
async function withdraw(amount) {
    const tx = await contract.withdrawUSDC(amount);
    await tx.wait();
    console.log("Withdrawal successful!");
}
```

### Funciones Administrativas (Solo Owner)

```javascript
// Agregar nuevo token
async function addToken(tokenAddress, requiresSwap) {
    const tx = await contract.addSupportedToken(tokenAddress, requiresSwap);
    await tx.wait();
    console.log("Token added!");
}

// Agregar soporte para ETH
async function addETH() {
    const tx = await contract.addETHSupport();
    await tx.wait();
    console.log("ETH support added!");
}

// Remover token
async function removeToken(tokenAddress) {
    const tx = await contract.removeSupportedToken(tokenAddress);
    await tx.wait();
    console.log("Token removed!");
}
```

---

## 🎯 Decisiones de Diseño

### 1. ¿Por qué TODO en USDC?

**Decisión**: Convertir todos los depósitos a USDC y mantener un único balance.

**Razones**:
- **Simplicidad UX**: Usuario solo ve "tengo X USDC en el banco"
- **Gas optimizado**: Un mapping simple vs anidado complejo
- **Contabilidad clara**: Todo en mismo denominador
- **Retiros directos**: Sin necesidad de reverse swaps

**Trade-offs**:
- ✅ UX dramáticamente mejorada
- ✅ Menos complejidad en contratos
- ✅ Menor consumo de gas
- ⚠️ Usuario pierde exposición a tokens originales (por diseño)
- ⚠️ Costos de swap en cada depósito

**Alternativa considerada**: Mantener tokens originales + tracking USD
- ❌ Complejidad extrema en retiros
- ❌ Más gas en todas las operaciones
- ❌ Difícil gestión de liquidez

### 2. ¿Por qué 0.5% de Slippage Máximo?

**Decisión**: MAX_SLIPPAGE_BP = 50 (0.5%)

**Análisis de mercado**:
- Uniswap V2 en pares principales: 0.1-0.3% slippage típico
- 0.5% cubre volatilidad normal + comisiones de swap (0.3%)
- Previene front-running extremo

**Configuración por tipo de activo**:
| Par | Liquidez | Slippage típico | Justificación 0.5% |
|-----|----------|----------------|-------------------|
| ETH/USDC | Alta ($100M+) | 0.1% | ✅ Más que suficiente |
| WBTC/USDC | Alta ($50M+) | 0.15% | ✅ Cubierto |
| DAI/USDC | Muy Alta | 0.05% | ✅ Stablecoin swap |
| LINK/USDC | Media ($10M+) | 0.3% | ✅ Límite razonable |
| Token obscuro | Baja | >1% | ⚠️ Puede fallar (correcto) |

**Trade-off**: 
- ✅ Protege contra manipulación
- ⚠️ Puede fallar en tokens de baja liquidez (feature, not bug)

### 3. ¿Path Directo vs Vía WETH?

**Decisión**: Intentar path directo primero, fallback a WETH.

```solidity
function _getOptimalPath(address tokenIn, address tokenOut) {
    // Opción 1: Directo (si existe)
    if (factory.getPair(tokenIn, tokenOut) != address(0)) {
        return [tokenIn, tokenOut];  // 1 hop = menos gas
    }
    // Opción 2: Vía WETH
    return [tokenIn, WETH, tokenOut];  // 2 hops = más liquidez
}
```

**Análisis de casos**:

**Caso A: DAI → USDC (Directo)**
```
Pool DAI/USDC: $50M liquidez
Path: [DAI, USDC]
Gas: ~150k
Slippage: ~0.05%
✅ ÓPTIMO
```

**Caso B: LINK → USDC (Vía WETH)**
```
Pool LINK/USDC: $2M liquidez (bajo)
Pool LINK/WETH: $30M liquidez (alto)
Pool WETH/USDC: $100M liquidez (muy alto)

Path directo: [LINK, USDC]
- Gas: ~150k
- Slippage: ~0.8% ❌ (excede límite)

Path vía WETH: [LINK, WETH, USDC]
- Gas: ~250k (+100k)
- Slippage: ~0.35% ✅
✅ MEJOR opción
```

**Decisión**: El código intenta directo, pero puede fallar en runtime por slippage. En producción, considerar:
- Lógica más sofisticada comparando liquidez
- Off-chain calculation del mejor path
- Parámetro `preferredPath` del usuario

### 4. ¿Por qué No Permitir Retiros en Token Original?

**Decisión**: Solo retiros en USDC.

**Razones**:
1. **Complejidad técnica**: Reverse swap requiere:
   - Mantener inventario de múltiples tokens
   - Gestionar liquidez para swaps inversos
   - Más aprobaciones y estado

2. **Riesgo de liquidez**:
   ```
   Usuario deposita: 10 ETH → 20,000 USDC
   Usuario quiere retirar: 10 ETH
   
   Problema: Contrato solo tiene USDC
   Solución: Swap USDC → ETH
   Riesgo: ¿Qué si no hay liquidez suficiente?
   ```

3. **Gas prohibitivo**: Cada retiro necesitaría 2 transacciones (swap + transfer)

**Solución actual**:
```
Usuario retira USDC → Usuario hace su propio swap en DEX
Ventaja: Usuario controla slippage y timing del swap inverso
```

**Para V4**: Considerar función opcional `withdrawAs(token)` con advertencias claras.
