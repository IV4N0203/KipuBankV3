// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

/**
 * @title KipuBankV3
 * @author IV4N0203 - AIR.dev
 * @notice Smart contract bancario avanzado que acepta cualquier token soportado por Uniswap V2,
 *         lo intercambia automáticamente a USDC y gestiona balances en USDC
 * @dev Integra Uniswap V2 Router para swaps automáticos, mantiene toda la funcionalidad de V2
 *      y respeta el bank cap en valor USDC
 * @custom:security No usar en producción.
 */
contract KipuBankV3 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========== TYPE DECLARATIONS ==========

    /**
     * @notice Estructura para almacenar información de tokens soportados
     * @param isSupported Indica si el token está activo en el banco
     * @param requiresSwap Si true, el token debe ser swapeado a USDC; si false, se deposita directamente
     */
    struct TokenInfo {
        bool isSupported;
        bool requiresSwap;
    }

    /**
     * @notice Estructura para estadísticas por token depositado
     * @param totalDeposited Total depositado de este token (en unidades del token original)
     * @param depositCount Número de depósitos realizados
     * @param totalSwappedToUSDC Total convertido a USDC desde este token
     */
    struct TokenStats {
        uint256 totalDeposited;
        uint256 depositCount;
        uint256 totalSwappedToUSDC;
    }

    // ========== STATE VARIABLES ==========

    // Constants
    /**
     * @notice Dirección especial que representa ETH nativo
     */
    address public constant NATIVE_TOKEN = address(0);

    /**
     * @notice Slippage máximo permitido para swaps (en basis points: 100 = 1%)
     * @dev 50 basis points = 0.5% de slippage máximo
     */
    uint256 public constant MAX_SLIPPAGE_BP = 50;

    /**
     * @notice Denominador para cálculos de basis points
     */
    uint256 public constant BASIS_POINTS = 10000;

    // Immutable
    /**
     * @notice Límite máximo del banco en USDC (con 6 decimales)
     */
    uint256 public immutable i_bankCapUSDC;

    /**
     * @notice Umbral máximo de retiro en USDC por transacción
     */
    uint256 public immutable i_withdrawalThresholdUSDC;

    /**
     * @notice Dirección del Uniswap V2 Router
     */
    IUniswapV2Router02 public immutable i_uniswapRouter;

    /**
     * @notice Dirección del Uniswap V2 Factory
     */
    IUniswapV2Factory public immutable i_uniswapFactory;

    /**
     * @notice Dirección del token USDC
     */
    address public immutable i_usdc;

    /**
     * @notice Dirección de WETH (para swaps de ETH)
     */
    address public immutable i_weth;

    // Storage
    /**
     * @notice Total de USDC depositado actualmente en el banco
     */
    uint256 private s_totalUSDCBalance;

    /**
     * @notice Contador total de operaciones de depósito
     */
    uint256 public s_depositCount;

    /**
     * @notice Contador total de operaciones de retiro
     */
    uint256 public s_withdrawalCount;

    /**
     * @notice Mapeo de información de tokens soportados
     */
    mapping(address token => TokenInfo info) private s_tokenInfo;

    /**
     * @notice Mapeo de balances de usuarios en USDC
     * @dev Todos los balances se mantienen en USDC para simplicidad
     */
    mapping(address user => uint256 usdcBalance) private s_balances;

    /**
     * @notice Mapeo de estadísticas por token
     */
    mapping(address token => TokenStats stats) private s_tokenStats;

    /**
     * @notice Lista de tokens soportados para iteración
     */
    address[] private s_supportedTokens;

    // ========== EVENTS ==========

    /**
     * @notice Emitido cuando un usuario realiza un depósito exitoso
     * @param user Dirección del usuario
     * @param tokenIn Token depositado (address(0) para ETH)
     * @param amountIn Cantidad depositada en unidades del token
     * @param usdcReceived Cantidad de USDC recibida (post-swap si aplica)
     * @param newBalance Nuevo balance total del usuario en USDC
     */
    event DepositMade(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 usdcReceived,
        uint256 newBalance
    );

    /**
     * @notice Emitido cuando un usuario realiza un retiro exitoso
     * @param user Dirección del usuario
     * @param amountUSDC Cantidad de USDC retirada
     * @param remainingBalance Balance restante en USDC
     */
    event WithdrawalMade(
        address indexed user,
        uint256 amountUSDC,
        uint256 remainingBalance
    );

    /**
     * @notice Emitido cuando se realiza un swap exitoso
     * @param user Usuario que realizó el depósito
     * @param tokenIn Token de entrada
     * @param amountIn Cantidad de entrada
     * @param usdcOut USDC recibido del swap
     */
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 usdcOut
    );

    /**
     * @notice Emitido cuando se agrega un nuevo token soportado
     * @param token Dirección del token
     * @param requiresSwap Si requiere swap a USDC
     */
    event TokenAdded(address indexed token, bool requiresSwap);

    /**
     * @notice Emitido cuando se remueve un token
     * @param token Dirección del token removido
     */
    event TokenRemoved(address indexed token);

    // ========== ERRORS ==========

    error KipuBankV3__ZeroAmount();
    error KipuBankV3__ZeroAddress();
    error KipuBankV3__TokenNotSupported(address token);
    error KipuBankV3__TokenAlreadySupported(address token);
    error KipuBankV3__InsufficientBalance(uint256 requested, uint256 available);
    error KipuBankV3__ExceedsBankCapacity(uint256 attempted, uint256 available);
    error KipuBankV3__ExceedsWithdrawalThreshold(uint256 requested, uint256 maxAllowed);
    error KipuBankV3__TransferFailed();
    error KipuBankV3__SwapFailed(string reason);
    error KipuBankV3__NoLiquidityPool(address tokenA, address tokenB);
    error KipuBankV3__SlippageTooHigh(uint256 expected, uint256 received);
    error KipuBankV3__InvalidDeadline();
    error KipuBankV3__CannotRemoveUSDC();

    // ========== MODIFIERS ==========

    /**
     * @notice Valida que la cantidad no sea cero
     */
    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) revert KipuBankV3__ZeroAmount();
        _;
    }

    /**
     * @notice Valida que el token esté soportado
     */
    modifier onlySupportedToken(address _token) {
        if (!s_tokenInfo[_token].isSupported) {
            revert KipuBankV3__TokenNotSupported(_token);
        }
        _;
    }

    /**
     * @notice Valida que el usuario tenga balance suficiente
     */
    modifier hasSufficientBalance(address _user, uint256 _amount) {
        if (s_balances[_user] < _amount) {
            revert KipuBankV3__InsufficientBalance(_amount, s_balances[_user]);
        }
        _;
    }

    // ========== CONSTRUCTOR ==========

    /**
     * @notice Inicializa KipuBankV3 con los parámetros especificados
     * @param _bankCapUSDC Límite máximo del banco en USDC (6 decimales)
     * @param _withdrawalThresholdUSDC Límite de retiro por transacción en USDC
     * @param _uniswapRouter Dirección del Uniswap V2 Router
     * @param _usdc Dirección del token USDC
     * @dev El USDC se agrega automáticamente como token soportado sin swap
     */
    constructor(
        uint256 _bankCapUSDC,
        uint256 _withdrawalThresholdUSDC,
        address _uniswapRouter,
        address _usdc
    ) Ownable(msg.sender) {
        if (_bankCapUSDC == 0 || _withdrawalThresholdUSDC == 0) {
            revert KipuBankV3__ZeroAmount();
        }
        if (_uniswapRouter == address(0) || _usdc == address(0)) {
            revert KipuBankV3__ZeroAddress();
        }

        i_bankCapUSDC = _bankCapUSDC;
        i_withdrawalThresholdUSDC = _withdrawalThresholdUSDC;
        i_uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        i_uniswapFactory = IUniswapV2Factory(i_uniswapRouter.factory());
        i_usdc = _usdc;
        i_weth = i_uniswapRouter.WETH();

        // Configurar USDC como token soportado (no requiere swap)
        s_tokenInfo[i_usdc] = TokenInfo({isSupported: true, requiresSwap: false});
        s_supportedTokens.push(i_usdc);

        emit TokenAdded(i_usdc, false);
    }

    // ========== EXTERNAL DEPOSIT FUNCTIONS ==========

    /**
     * @notice Deposita ETH nativo, lo swapea a USDC y acredita al usuario
     * @dev El ETH se convierte a WETH y luego se swapea a USDC vía Uniswap V2
     */
    function depositETH() external payable nonZeroAmount(msg.value) nonReentrant {
        // ETH siempre requiere swap a USDC
        if (!s_tokenInfo[NATIVE_TOKEN].isSupported) {
            revert KipuBankV3__TokenNotSupported(NATIVE_TOKEN);
        }

        // Realizar swap de ETH a USDC
        uint256 usdcReceived = _swapETHToUSDC(msg.value);

        // Verificar bank cap
        _checkBankCapacity(usdcReceived);

        // Actualizar balances
        s_balances[msg.sender] += usdcReceived;
        s_totalUSDCBalance += usdcReceived;
        s_depositCount++;

        // Actualizar estadísticas del token
        s_tokenStats[NATIVE_TOKEN].totalDeposited += msg.value;
        s_tokenStats[NATIVE_TOKEN].depositCount++;
        s_tokenStats[NATIVE_TOKEN].totalSwappedToUSDC += usdcReceived;

        emit DepositMade(msg.sender, NATIVE_TOKEN, msg.value, usdcReceived, s_balances[msg.sender]);
    }

    /**
     * @notice Deposita tokens ERC20, los swapea a USDC si es necesario y acredita al usuario
     * @param _token Dirección del token ERC20
     * @param _amount Cantidad de tokens a depositar
     * @dev Si el token es USDC, se deposita directamente. Otros tokens se swapean.
     */
    function depositToken(address _token, uint256 _amount)
        external
        nonZeroAmount(_amount)
        onlySupportedToken(_token)
        nonReentrant
    {
        if (_token == NATIVE_TOKEN) revert KipuBankV3__TokenNotSupported(_token);

        TokenInfo memory tokenInfo = s_tokenInfo[_token];
        uint256 usdcReceived;

        // Transferir tokens del usuario al contrato
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        if (tokenInfo.requiresSwap) {
            // Token que no es USDC: hacer swap
            usdcReceived = _swapTokenToUSDC(_token, _amount);
        } else {
            // Es USDC: depositar directamente
            usdcReceived = _amount;
        }

        // Verificar bank cap
        _checkBankCapacity(usdcReceived);

        // Actualizar balances
        s_balances[msg.sender] += usdcReceived;
        s_totalUSDCBalance += usdcReceived;
        s_depositCount++;

        // Actualizar estadísticas
        s_tokenStats[_token].totalDeposited += _amount;
        s_tokenStats[_token].depositCount++;
        if (tokenInfo.requiresSwap) {
            s_tokenStats[_token].totalSwappedToUSDC += usdcReceived;
        }

        emit DepositMade(msg.sender, _token, _amount, usdcReceived, s_balances[msg.sender]);
    }

    // ========== EXTERNAL WITHDRAWAL FUNCTIONS ==========

    /**
     * @notice Retira USDC del banco
     * @param _amount Cantidad de USDC a retirar
     * @dev Los retiros siempre son en USDC independientemente del token depositado
     */
    function withdrawUSDC(uint256 _amount)
        external
        nonZeroAmount(_amount)
        hasSufficientBalance(msg.sender, _amount)
        nonReentrant
    {
        // Verificar umbral de retiro
        if (_amount > i_withdrawalThresholdUSDC) {
            revert KipuBankV3__ExceedsWithdrawalThreshold(_amount, i_withdrawalThresholdUSDC);
        }

        // Actualizar estado
        s_balances[msg.sender] -= _amount;
        s_totalUSDCBalance -= _amount;
        s_withdrawalCount++;

        // Transferir USDC al usuario
        IERC20(i_usdc).safeTransfer(msg.sender, _amount);

        emit WithdrawalMade(msg.sender, _amount, s_balances[msg.sender]);
    }

    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Agrega un nuevo token soportado (solo owner)
     * @param _token Dirección del token
     * @param _requiresSwap Si el token debe swapearse a USDC o no
     * @dev Solo USDC debe tener requiresSwap = false
     */
    function addSupportedToken(address _token, bool _requiresSwap) external onlyOwner {
        if (_token == address(0)) revert KipuBankV3__ZeroAddress();
        if (s_tokenInfo[_token].isSupported) {
            revert KipuBankV3__TokenAlreadySupported(_token);
        }

        // Validar que existe pool de liquidez en Uniswap si requiere swap
        if (_requiresSwap) {
            _validateLiquidityPool(_token);
        }

        s_tokenInfo[_token] = TokenInfo({isSupported: true, requiresSwap: _requiresSwap});
        s_supportedTokens.push(_token);

        emit TokenAdded(_token, _requiresSwap);
    }

    /**
     * @notice Agrega soporte para ETH nativo (solo owner)
     * @dev ETH siempre requiere swap vía WETH
     */
    function addETHSupport() external onlyOwner {
        if (s_tokenInfo[NATIVE_TOKEN].isSupported) {
            revert KipuBankV3__TokenAlreadySupported(NATIVE_TOKEN);
        }

        // Validar que existe pool WETH/USDC
        address pair = i_uniswapFactory.getPair(i_weth, i_usdc);
        if (pair == address(0)) {
            revert KipuBankV3__NoLiquidityPool(i_weth, i_usdc);
        }

        s_tokenInfo[NATIVE_TOKEN] = TokenInfo({isSupported: true, requiresSwap: true});
        s_supportedTokens.push(NATIVE_TOKEN);

        emit TokenAdded(NATIVE_TOKEN, true);
    }

    /**
     * @notice Remueve un token soportado (solo owner)
     * @param _token Dirección del token a remover
     * @dev No se puede remover USDC
     */
    function removeSupportedToken(address _token) external onlyOwner {
        if (_token == i_usdc) revert KipuBankV3__CannotRemoveUSDC();
        if (!s_tokenInfo[_token].isSupported) {
            revert KipuBankV3__TokenNotSupported(_token);
        }

        s_tokenInfo[_token].isSupported = false;

        emit TokenRemoved(_token);
    }

    // ========== INTERNAL/PRIVATE SWAP FUNCTIONS ==========

    /**
     * @notice Swapea ETH a USDC usando Uniswap V2
     * @param _amountETH Cantidad de ETH a swapear
     * @return amountUSDC Cantidad de USDC recibida
     */
    function _swapETHToUSDC(uint256 _amountETH) private returns (uint256 amountUSDC) {
        // Preparar path: ETH -> WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = i_weth;
        path[1] = i_usdc;

        // Calcular mínimo de salida con slippage
        uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amountETH, path);
        uint256 minAmountOut = (amountsOut[1] * (BASIS_POINTS - MAX_SLIPPAGE_BP)) / BASIS_POINTS;

        // Ejecutar swap
        uint256[] memory amounts = i_uniswapRouter.swapExactETHForTokens{value: _amountETH}(
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300 // 5 minutos de deadline
        );

        amountUSDC = amounts[1];

        emit SwapExecuted(msg.sender, NATIVE_TOKEN, _amountETH, amountUSDC);

        return amountUSDC;
    }

    /**
     * @notice Swapea un token ERC20 a USDC usando Uniswap V2
     * @param _tokenIn Dirección del token de entrada
     * @param _amountIn Cantidad de tokens a swapear
     * @return amountUSDC Cantidad de USDC recibida
     */
    function _swapTokenToUSDC(address _tokenIn, uint256 _amountIn)
        private
        returns (uint256 amountUSDC)
    {
        // Aprobar el router para gastar los tokens
        IERC20(_tokenIn).safeIncreaseAllowance(address(i_uniswapRouter), _amountIn);

        // Preparar path: Token -> USDC (o Token -> WETH -> USDC si no hay par directo)
        address[] memory path = _getOptimalPath(_tokenIn, i_usdc);

        // Calcular mínimo de salida con slippage
        uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amountIn, path);
        uint256 minAmountOut = (amountsOut[amountsOut.length - 1] * (BASIS_POINTS - MAX_SLIPPAGE_BP)) / BASIS_POINTS;

        // Ejecutar swap
        uint256[] memory amounts = i_uniswapRouter.swapExactTokensForTokens(
            _amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300 // 5 minutos de deadline
        );

        amountUSDC = amounts[amounts.length - 1];

        emit SwapExecuted(msg.sender, _tokenIn, _amountIn, amountUSDC);

        return amountUSDC;
    }

    /**
     * @notice Determina el path óptimo para el swap
     * @param _tokenIn Token de entrada
     * @param _tokenOut Token de salida
     * @return path Array con la ruta óptima del swap
     * @dev Intenta primero par directo, luego vía WETH si es necesario
     */
    function _getOptimalPath(address _tokenIn, address _tokenOut)
        private
        view
        returns (address[] memory path)
    {
        // Verificar si existe par directo
        address directPair = i_uniswapFactory.getPair(_tokenIn, _tokenOut);

        if (directPair != address(0)) {
            // Existe par directo
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            // Usar WETH como intermediario
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = i_weth;
            path[2] = _tokenOut;
        }

        return path;
    }

    /**
     * @notice Verifica que no se exceda la capacidad del banco
     * @param _usdcAmount Valor a agregar en USDC
     */
    function _checkBankCapacity(uint256 _usdcAmount) private view {
        uint256 newTotalBalance = s_totalUSDCBalance + _usdcAmount;
        if (newTotalBalance > i_bankCapUSDC) {
            revert KipuBankV3__ExceedsBankCapacity(
                _usdcAmount,
                i_bankCapUSDC - s_totalUSDCBalance
            );
        }
    }

    /**
     * @notice Valida que existe liquidez para el token en Uniswap
     * @param _token Token a validar
     */
    function _validateLiquidityPool(address _token) private view {
        // Verificar par directo con USDC
        address directPair = i_uniswapFactory.getPair(_token, i_usdc);
        
        if (directPair == address(0)) {
            // Si no hay par directo, verificar par con WETH
            address wethPair = i_uniswapFactory.getPair(_token, i_weth);
            if (wethPair == address(0)) {
                revert KipuBankV3__NoLiquidityPool(_token, i_usdc);
            }
        }
    }

    // ========== VIEW/PURE FUNCTIONS ==========

    /**
     * @notice Obtiene el balance de un usuario en USDC
     * @param _user Dirección del usuario
     * @return balance Balance del usuario en USDC
     */
    function getUserBalance(address _user) external view returns (uint256 balance) {
        return s_balances[_user];
    }

    /**
     * @notice Obtiene estadísticas generales del banco
     * @return totalUSDC Total de USDC en el banco
     * @return remainingCapacity Capacidad restante en USDC
     * @return supportedTokensCount Cantidad de tokens soportados
     * @return totalDeposits Número total de depósitos
     * @return totalWithdrawals Número total de retiros
     */
    function getBankStats()
        external
        view
        returns (
            uint256 totalUSDC,
            uint256 remainingCapacity,
            uint256 supportedTokensCount,
            uint256 totalDeposits,
            uint256 totalWithdrawals
        )
    {
        return (
            s_totalUSDCBalance,
            i_bankCapUSDC - s_totalUSDCBalance,
            s_supportedTokens.length,
            s_depositCount,
            s_withdrawalCount
        );
    }

    /**
     * @notice Obtiene estadísticas de un token específico
     * @param _token Dirección del token
     * @return stats Estructura TokenStats con las estadísticas
     */
    function getTokenStats(address _token) external view returns (TokenStats memory stats) {
        return s_tokenStats[_token];
    }

    /**
     * @notice Obtiene información de un token
     * @param _token Dirección del token
     * @return info Estructura TokenInfo con la información
     */
    function getTokenInfo(address _token) external view returns (TokenInfo memory info) {
        return s_tokenInfo[_token];
    }

    /**
     * @notice Obtiene la lista de tokens soportados
     * @return tokens Array de direcciones de tokens soportados
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return s_supportedTokens;
    }

    /**
     * @notice Estima cuánto USDC recibirá un usuario por un depósito
     * @param _token Token a depositar
     * @param _amount Cantidad a depositar
     * @return estimatedUSDC USDC estimado a recibir (considerando slippage)
     */
    function estimateDepositOutput(address _token, uint256 _amount)
        external
        view
        onlySupportedToken(_token)
        returns (uint256 estimatedUSDC)
    {
        if (_token == i_usdc) {
            return _amount;
        }

        address[] memory path;
        if (_token == NATIVE_TOKEN) {
            path = new address[](2);
            path[0] = i_weth;
            path[1] = i_usdc;
        } else {
            path = _getOptimalPath(_token, i_usdc);
        }

        uint256[] memory amountsOut = i_uniswapRouter.getAmountsOut(_amount, path);
        estimatedUSDC = (amountsOut[amountsOut.length - 1] * (BASIS_POINTS - MAX_SLIPPAGE_BP)) / BASIS_POINTS;

        return estimatedUSDC;
    }

    /**
     * @notice Verifica si un par de tokens tiene liquidez en Uniswap
     * @param _tokenA Primera dirección de token
     * @param _tokenB Segunda dirección de token
     * @return hasLiquidity True si existe el par
     */
    function checkLiquidityPool(address _tokenA, address _tokenB)
        external
        view
        returns (bool hasLiquidity)
    {
        address pair = i_uniswapFactory.getPair(_tokenA, _tokenB);
        return pair != address(0);
    }

    // ========== RECEIVE/FALLBACK ==========

    receive() external payable {
        revert("Use depositETH() function");
    }

    fallback() external {
        revert("Function does not exist");
    }
}
