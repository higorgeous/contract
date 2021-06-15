// SPDX-License-Identifier: MIT

// GORGEOUS - Gorgeous: BEP20 token contract
// Telegram: https://t.me/gorgeoustoken
// Website: https://www.higorgeous.io/

// TOKENOMICS
// ----------------------------------------------------------------------------
// Symbol: GORGEOUS
// Name: Gorgeous
// Total supply: 100,000,000.000000000000000000
// Decimals: 9
// ----------------------------------------------------------------------------
// Max buy 2% max, hold 5%
// 50% Burnt to dead wallet
// 40% Liquidity in pool
// Ownership renounced
// ----------------------------------------------------------------------------
// Sell within 1 hour: 35% burn (1% Burn, 10% Back to the Liquidity Pool, 7% To charity wallet, 7% To project wallet, 9% Redistributed to Holders)
// Sell within 2 hours: 25% burn (1% Burn, 8% Back to the Liquidity Pool, 5% To charity wallet, 5% To project wallet, 7% Redistributed to Holders)
// Standard burn: 15% burn (1% Burn, 4% Back to the Liquidity Pool, 3% To charity wallet, 3% To project wallet, 4% Redistributed to Holders)
// ----------------------------------------------------------------------------

pragma solidity ^0.8.5;

import "./GorgeousTokenImports.sol";

abstract contract Tokenomics {
    string internal constant NAME = "Gorgeous Token";
    string internal constant SYMBOL = "GORGEOUS";

    uint16 internal constant TOKENOMICS_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 9;
    uint256 internal constant ZEROES = 10**DECIMALS;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 100 * 10**6 * ZEROES;
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * Set the maximum buy to 2%.
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 50;

    /**
     * Set the maximum hold to 5%.
     */
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 20;

    /**
     * Set the number of tokens to swap and add to liquidity.
     *
     * When the contract's balance reaches 0.1% of tokens, swap & liquify will be
     * executed in the next transfer with function `_beforeTokenTransfer`
     *
     * Once the contract's balance reaches `numberOfTokensToSwapToLiquidity`, `swapAndLiquify`
     * of `Liquifier` will be executed. Half of the tokens will be swapped for BNB and together
     * with the other half converted into a Token-BNB LP Token.
     *
     * See: `Liquifier`
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 1000; // 0.1% of the total supply

    /**
     * Contract specific address'
     */
    address internal charityAddress =
        0x6ea97adae69Ff80E418Ea78E80Ae9ab2f2254389;
    address internal projectAddress =
        0x5DDB6ABD2e3A1f23f15a77227d9652c94341AA57;
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    /**
     * Address to get time token was last received
     */
    mapping(address => uint256) lastReceived;

    enum TokenomicType {Burn, Liquidity, Redistribution, Project, External}
    struct Tokenomic {
        TokenomicType name;
        uint256 value;
        address recipient;
        uint256 total;
    }

    Tokenomic[] internal tokenomics;
    uint256 internal sumOfTokenomics;

    constructor() {
        _addTokenomics();
    }

    function _addTokenomic(
        TokenomicType name,
        uint256 value,
        address recipient
    ) private {
        tokenomics.push(Tokenomic(name, value, recipient, 0));
        sumOfTokenomics += value;
        _updateLastReceived(recipient);
    }

    function _getDistMultiplier(address _sender)
        internal
        view
        returns (uint256)
    {
        uint256 timeReceived = block.timestamp - lastReceived[_sender];
        if (timeReceived < 1 hours) {
            return 100;
        } else if (timeReceived < 2 hours) {
            return 70;
        }
        return 40;
    }

    function _getProjectMultiplier(address _sender)
        internal
        view
        returns (uint256)
    {
        uint256 timeReceived = block.timestamp - lastReceived[_sender];
        if (timeReceived < 1 hours) {
            return 70;
        } else if (timeReceived < 2 hours) {
            return 50;
        }
        return 30;
    }

    function _updateLastReceived(address _receiver) internal {
        lastReceived[_receiver] = block.timestamp;
    }

    function _addTokenomics() private {
        uint256 cfee = _getDistMultiplier(msg.sender);
        uint256 pfee = _getProjectMultiplier(msg.sender);

        _addTokenomic(TokenomicType.Redistribution, cfee, address(this));

        _addTokenomic(TokenomicType.Burn, 10, burnAddress);
        _addTokenomic(TokenomicType.Liquidity, cfee, address(this));
        _addTokenomic(TokenomicType.Project, pfee, charityAddress);
        _addTokenomic(TokenomicType.Project, pfee, projectAddress);
    }

    function _getTokenomicsCount() internal view returns (uint256) {
        return tokenomics.length;
    }

    function _getTokenomicStruct(uint256 index)
        private
        view
        returns (Tokenomic storage)
    {
        require(
            index >= 0 && index < tokenomics.length,
            "TokenomicSettings._getTokenomicStruct: Tokenomic index out of bounds"
        );
        return tokenomics[index];
    }

    function _getTokenomic(uint256 index)
        internal
        view
        returns (
            TokenomicType,
            uint256,
            address,
            uint256
        )
    {
        Tokenomic memory tokenomic = _getTokenomicStruct(index);
        return (
            tokenomic.name,
            tokenomic.value,
            tokenomic.recipient,
            tokenomic.total
        );
    }

    function _addTokenomicCollectedAmount(uint256 index, uint256 amount)
        internal
    {
        Tokenomic storage tokenomic = _getTokenomicStruct(index);
        tokenomic.total = tokenomic.total + amount;
    }

    function getCollectedTokenomicTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Tokenomic memory tokenomic = _getTokenomicStruct(index);
        return tokenomic.total;
    }
}

abstract contract Presaleable is Manageable {
    bool internal isInPresale;

    function setPreseableEnabled(bool value) external onlyManager {
        isInPresale = value;
    }
}

abstract contract BaseRedistribution is
    IERC20,
    IERC20Metadata,
    Ownable,
    Presaleable,
    Tokenomics
{
    using Address for address;

    mapping(address => uint256) internal _reflectedBalances;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    mapping(address => bool) internal _isExcludedFromTokenomics;
    mapping(address => bool) internal _isExcludedFromRewards;
    address[] private _excluded;

    constructor() {
        _reflectedBalances[owner()] = _reflectedSupply;

        // exclude owner and this contract from tokenomics
        _isExcludedFromTokenomics[owner()] = true;
        _isExcludedFromTokenomics[address(this)] = true;

        // exclude the owner and this contract from rewards
        _exclude(owner());
        _exclude(address(this));

        emit Transfer(address(0), owner(), TOTAL_SUPPLY);
    }

    /** Functions required by IERC20Metadat **/
    function name() external pure override returns (string memory) {
        return NAME;
    }

    function symbol() external pure override returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    /** Functions required by IERC20 **/
    function totalSupply() external pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromRewards[account]) return _balances[account];
        return tokenFromReflection(_reflectedBalances[account]);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function burn(uint256 amount) external {
        address sender = _msgSender();
        require(
            sender != address(0),
            "BaseRedistribution: burn from the zero address"
        );
        require(
            sender != address(burnAddress),
            "BaseRedistribution: burn from the burn address"
        );

        uint256 balance = balanceOf(sender);
        require(
            balance >= amount,
            "BaseRedistribution: burn amount exceeds balance"
        );

        uint256 reflectedAmount = amount * _getCurrentRate();

        // remove the amount from the sender's balance first
        _reflectedBalances[sender] =
            _reflectedBalances[sender] -
            reflectedAmount;
        if (_isExcludedFromRewards[sender])
            _balances[sender] = _balances[sender] - amount;

        _burnTokens(sender, amount, reflectedAmount);
    }

    function _burnTokens(
        address sender,
        uint256 tBurn,
        uint256 rBurn
    ) internal {
        _reflectedBalances[burnAddress] =
            _reflectedBalances[burnAddress] +
            rBurn;
        if (_isExcludedFromRewards[burnAddress])
            _balances[burnAddress] = _balances[burnAddress] + tBurn;

        /**
         * Emit the event so that the burn address balance is updated on bscscan
         */
        emit Transfer(sender, burnAddress, tBurn);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcludedFromRewards[account];
    }

    /**
     * Calculates and returns the reflected amount for the given amount with or without
     * the transfer tokenomics (`deductTransferTokenomics` true/false)
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferTokenomics)
        external
        view
        returns (uint256)
    {
        require(tAmount <= TOTAL_SUPPLY, "Amount must be less than supply");
        if (!deductTransferTokenomics) {
            (uint256 rAmount, , , , ) = _getValues(tAmount, 0);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , ) =
                _getValues(tAmount, _getSumOfTokenomics(_msgSender(), tAmount));
            return rTransferAmount;
        }
    }

    /**
     * Calculates and returns the amount of tokens corresponding to the given reflected amount.
     */
    function tokenFromReflection(uint256 rAmount)
        internal
        view
        returns (uint256)
    {
        require(
            rAmount <= _reflectedSupply,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getCurrentRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) external onlyOwner() {
        require(!_isExcludedFromRewards[account], "Account is not included");
        _exclude(account);
    }

    function _exclude(address account) internal {
        if (_reflectedBalances[account] > 0) {
            _balances[account] = tokenFromReflection(
                _reflectedBalances[account]
            );
        }
        _isExcludedFromRewards[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcludedFromRewards[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _balances[account] = 0;
                _isExcludedFromRewards[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function setExcludedFromTokenomics(address account, bool value)
        external
        onlyOwner
    {
        _isExcludedFromTokenomics[account] = value;
    }

    function isExcludedFromTokenomics(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromTokenomics[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(
            owner != address(0),
            "BaseRedistribution: approve from the zero address"
        );
        require(
            spender != address(0),
            "BaseRedistribution: approve to the zero address"
        );

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _isUnlimitedSender(address account) internal view returns (bool) {
        // The owner is the only whitelisted sender until ownership is renounced
        return (account == owner());
    }

    function _isUnlimitedRecipient(address account)
        internal
        view
        returns (bool)
    {
        // The owner is the only whitelisted recipient until ownership is renounced
        return (account == owner() || account == burnAddress);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(
            sender != address(0),
            "BaseRedistribution: transfer from the zero address"
        );
        require(
            recipient != address(0),
            "BaseRedistribution: transfer to the zero address"
        );
        require(
            sender != address(burnAddress),
            "BaseRedistribution: transfer from the burn address"
        );
        require(amount > 0, "Transfer amount must be greater than zero");

        // Indicates whether or not tokenomics should be applied for the transfer
        bool takeTokenomics = true;

        if (isInPresale) {
            takeTokenomics = false;
        } else {
            /**
             * Check the amount is within the max allowed limit
             */
            if (
                amount > maxTransactionAmount &&
                !_isUnlimitedSender(sender) &&
                !_isUnlimitedRecipient(recipient)
            ) {
                revert("Transfer amount exceeds the maxTxAmount.");
            }
            /**
             * The pair needs to excluded from the max wallet balance check;
             * selling tokens is sending them back to the pair
             */
            if (
                maxWalletBalance > 0 &&
                !_isUnlimitedSender(sender) &&
                !_isUnlimitedRecipient(recipient) &&
                !_isV2Pair(recipient)
            ) {
                uint256 recipientBalance = balanceOf(recipient);
                require(
                    recipientBalance + amount <= maxWalletBalance,
                    "New balance would exceed the maxWalletBalance"
                );
            }
        }

        // Remove accounts that belong to _isExcludedFromTokenomics
        if (
            _isExcludedFromTokenomics[sender] ||
            _isExcludedFromTokenomics[recipient]
        ) {
            takeTokenomics = false;
        }

        _beforeTokenTransfer(sender, recipient, amount, takeTokenomics);
        _transferTokens(sender, recipient, amount, takeTokenomics);
        _updateLastReceived(recipient);
    }

    function _transferTokens(
        address sender,
        address recipient,
        uint256 amount,
        bool takeTokenomics
    ) private {
        uint256 sumOfTokenomics = _getSumOfTokenomics(sender, amount);
        if (!takeTokenomics) {
            sumOfTokenomics = 0;
        }

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tAmount,
            uint256 tTransferAmount,
            uint256 currentRate
        ) = _getValues(amount, sumOfTokenomics);

        /**
         * Sender's and Recipient's reflected balances must be always updated regardless of
         * whether they are excluded from rewards or not.
         */

        _reflectedBalances[sender] = _reflectedBalances[sender] - rAmount;
        _reflectedBalances[recipient] =
            _reflectedBalances[recipient] +
            rTransferAmount;

        /**
         * Update the true/nominal balances for excluded accounts
         */

        if (_isExcludedFromRewards[sender]) {
            _balances[sender] = _balances[sender] - tAmount;
        }
        if (_isExcludedFromRewards[recipient]) {
            _balances[recipient] = _balances[recipient] + tTransferAmount;
        }

        _takeTokenomics(amount, currentRate, sumOfTokenomics);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTokenomics(
        uint256 amount,
        uint256 currentRate,
        uint256 sumOfTokenomics
    ) private {
        if (sumOfTokenomics > 0 && !isInPresale) {
            _takeTransactionTokenomics(amount, currentRate);
        }
    }

    function _getValues(uint256 tAmount, uint256 tokenomicsSum)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tTotalTokenomics =
            (tAmount * tokenomicsSum) / TOKENOMICS_DIVISOR;
        uint256 tTransferAmount = tAmount - tTotalTokenomics;
        uint256 currentRate = _getCurrentRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rTotalTokenomics = tTotalTokenomics * currentRate;
        uint256 rTransferAmount = rAmount - rTotalTokenomics;

        return (
            rAmount,
            rTransferAmount,
            tAmount,
            tTransferAmount,
            currentRate
        );
    }

    function _getCurrentRate() internal view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() internal view returns (uint256, uint256) {
        uint256 rSupply = _reflectedSupply;
        uint256 tSupply = TOTAL_SUPPLY;

        /**
         * The code below removes balances of addresses excluded from rewards from
         * rSupply and tSupply, which effectively increases the % of transaction tokenomics
         * delivered to non-excluded holders
         */

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _reflectedBalances[_excluded[i]] > rSupply ||
                _balances[_excluded[i]] > tSupply
            ) return (_reflectedSupply, TOTAL_SUPPLY);
            rSupply = rSupply - _reflectedBalances[_excluded[i]];
            tSupply = tSupply - _balances[_excluded[i]];
        }
        if (tSupply == 0 || rSupply < _reflectedSupply / TOTAL_SUPPLY)
            return (_reflectedSupply, TOTAL_SUPPLY);
        return (rSupply, tSupply);
    }

    /**
     * Hook that is called before any transfer of tokens.
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeTokenomics
    ) internal virtual;

    /**
     * Returns the total sum of tokenomics to be processed in each transaction.
     */

    function _getSumOfTokenomics(address sender, uint256 amount)
        internal
        view
        virtual
        returns (uint256);

    /**
     * A delegate which should return true if the given address is the V2 Pair and false otherwise
     */
    function _isV2Pair(address account) internal view virtual returns (bool);

    /**
     * Redistributes the specified amount among the current holders
     */
    function _redistribute(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        uint256 index
    ) internal {
        uint256 tTokenomic = (amount * tokenomic) / TOKENOMICS_DIVISOR;
        uint256 rTokenomic = tTokenomic * currentRate;

        _reflectedSupply = _reflectedSupply - rTokenomic;
        _addTokenomicCollectedAmount(index, tTokenomic);
    }

    /**
     * Hook that is called before the `Transfer` event is emitted if tokenomics are enabled for the transfer
     */
    function _takeTransactionTokenomics(uint256 amount, uint256 currentRate)
        internal
        virtual;
}

abstract contract Liquifier is Ownable, Manageable {
    uint256 private withdrawableBalance;

    enum Env {Testnet, Mainnet}
    Env private _env;

    // PancakeSwap V2
    address private _mainnetRouterV2Address =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private _testnetRouterAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    IPancakeV2Router internal _router;
    address internal _pair;

    bool private inSwapAndLiquify;
    bool private swapAndLiquifyEnabled = true;

    uint256 private maxTransactionAmount;
    uint256 private numberOfTokensToSwapToLiquidity;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event RouterSet(address indexed router);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event LiquidityAdded(
        uint256 tokenAmountSent,
        uint256 bnbAmountSent,
        uint256 liquidity
    );

    receive() external payable {}

    function initializeLiquiditySwapper(
        Env env,
        uint256 maxTx,
        uint256 liquifyAmount
    ) internal {
        _env = env;
        if (_env == Env.Mainnet) {
            _setRouterAddress(_mainnetRouterV2Address);
        }
        /*(_env == Env.Testnet)*/
        else {
            _setRouterAddress(_testnetRouterAddress);
        }

        maxTransactionAmount = maxTx;
        numberOfTokensToSwapToLiquidity = liquifyAmount;
    }

    function liquify(uint256 contractTokenBalance, address sender) internal {
        if (contractTokenBalance >= maxTransactionAmount)
            contractTokenBalance = maxTransactionAmount;

        bool isOverRequiredTokenBalance =
            (contractTokenBalance >= numberOfTokensToSwapToLiquidity);

        if (
            isOverRequiredTokenBalance &&
            swapAndLiquifyEnabled &&
            !inSwapAndLiquify &&
            (sender != _pair)
        ) {
            _swapAndLiquify(contractTokenBalance);
        }
    }

    /**
     * sets the router address and created the router, factory pair to enable
     * swapping and liquifying (contract) tokens
     */
    function _setRouterAddress(address router) private {
        IPancakeV2Router _newPancakeRouter = IPancakeV2Router(router);
        _pair = IPancakeV2Factory(_newPancakeRouter.factory()).createPair(
            address(this),
            _newPancakeRouter.WETH()
        );
        _router = _newPancakeRouter;
        emit RouterSet(router);
    }

    function _swapAndLiquify(uint256 amount) private lockTheSwap {
        // Split the contract balance into halves
        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        // Capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // Swap tokens for BNB
        _swapTokensForBnb(half); // <- this breaks the BNB -> HATE swap when swap+liquify is triggered

        // How much BNB did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // Add liquidity to pancakeswap
        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapTokensForBnb(uint256 tokenAmount) private {
        // Generate the pancakeswap pair path of token -> bnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();

        _approveDelegate(address(this), address(_router), tokenAmount);

        // Make the swap
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            // The minimum amount of output tokens that must be received for the transaction not to revert.
            // 0 = accept any amount (slippage is inevitable)
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approveDelegate(address(this), address(_router), tokenAmount);

        // Add the liquidity
        (uint256 tokenAmountSent, uint256 ethAmountSent, uint256 liquidity) =
            _router.addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                // Bounds the extent to which the BNB/token price can go up before the transaction reverts.
                // Must be <= amountTokenDesired; 0 = accept any amount (slippage is inevitable)
                0,
                // Bounds the extent to which the token/BNB price can go up before the transaction reverts.
                // 0 = accept any amount (slippage is inevitable)
                0,
                // This is a centralized risk if the owner's account is ever compromised.
                owner(),
                block.timestamp
            );

        /**
         * The swapAndLiquify function converts half of the contractTokenBalance SafeMoon tokens to BNB.
         * For every swapAndLiquify function call, a small amount of BNB remains in the contract.
         * This amount grows over time with the swapAndLiquify function being called throughout the life
         * of the contract. The Safemoon contract does not contain a method to withdraw these funds,
         * and the BNB will be locked in the Safemoon contract forever.
         */
        withdrawableBalance = address(this).balance;
        emit LiquidityAdded(tokenAmountSent, ethAmountSent, liquidity);
    }

    /**
     * Sets the pancakeswapV2 pair (router & factory) for swapping and liquifying tokens
     */
    function setRouterAddress(address router) external onlyManager() {
        _setRouterAddress(router);
    }

    /**
     * Sends the swap and liquify flag to the provided value. If set to `false` tokens collected in the contract will
     * NOT be converted into liquidity.
     */
    function setSwapAndLiquifyEnabled(bool enabled) external onlyManager {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(swapAndLiquifyEnabled);
    }

    /**
     * The owner can withdraw BNB collected in the contract from `swapAndLiquify`
     * or if someone (accidentally) sends BNB directly to the contract.
     *
     * Note: This addresses the contract flaw of Safemoon (SSL-03) pointed out in the Certik Audit:
     */
    function withdrawLockedBnb(address payable recipient)
        external
        onlyManager()
    {
        require(
            recipient != address(0),
            "Cannot withdraw the BNB balance to the zero address"
        );
        require(
            withdrawableBalance > 0,
            "The BNB balance must be greater than 0"
        );

        // prevent re-entrancy attacks
        uint256 amount = withdrawableBalance;
        withdrawableBalance = 0;
        recipient.transfer(amount);
    }

    /**
     * Use this delegate instead of having (unnecessarily) extend `BaseRedistributionToken` to gained access
     * to the `_approve` function.
     */
    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual;
}

abstract contract Antiwhale is Tokenomics {
    /**
     * Returns the total sum of tokenomics (in percents / per-mille)
     */
    function _getAntiwhaleTokenomics(uint256, uint256)
        internal
        view
        returns (uint256)
    {
        return sumOfTokenomics;
    }
}

abstract contract GorgeousToken is BaseRedistribution, Liquifier, Antiwhale {
    constructor(Env _env) {
        initializeLiquiditySwapper(
            _env,
            maxTransactionAmount,
            numberOfTokensToSwapToLiquidity
        );

        // exclude the pair address from rewards - we don't want to redistribute
        // tokenomics to these two; redistribution is only for holders!
        _exclude(_pair);
        _exclude(burnAddress);
    }

    function _isV2Pair(address account) internal view override returns (bool) {
        return (account == _pair);
    }

    function _getSumOfTokenomics(address sender, uint256 amount)
        internal
        view
        override
        returns (uint256)
    {
        return _getAntiwhaleTokenomics(balanceOf(sender), amount);
    }

    function _beforeTokenTransfer(
        address sender,
        address,
        uint256,
        bool
    ) internal override {
        if (!isInPresale) {
            uint256 contractTokenBalance = balanceOf(address(this));
            liquify(contractTokenBalance, sender);
        }
    }

    function _takeTransactionTokenomics(uint256 amount, uint256 currentRate)
        internal
        override
    {
        if (isInPresale) {
            return;
        }

        uint256 tokenomicsCount = _getTokenomicsCount();
        for (uint256 index = 0; index < tokenomicsCount; index++) {
            (TokenomicType name, uint256 value, address recipient, ) =
                _getTokenomic(index);
            // no need to check value < 0 as the value is uint (i.e. from 0 to 2^256-1)
            if (value == 0) continue;

            if (name == TokenomicType.Redistribution) {
                _redistribute(amount, currentRate, value, index);
            } else if (name == TokenomicType.Burn) {
                _burn(amount, currentRate, value, index);
            } else {
                _takeTokenomics(amount, currentRate, value, recipient, index);
            }
        }
    }

    function _burn(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        uint256 index
    ) private {
        uint256 tBurn = (amount * tokenomic) / TOKENOMICS_DIVISOR;
        uint256 rBurn = tBurn * currentRate;

        _burnTokens(address(this), tBurn, rBurn);
        _addTokenomicCollectedAmount(index, tBurn);
    }

    function _takeTokenomics(
        uint256 amount,
        uint256 currentRate,
        uint256 tokenomic,
        address recipient,
        uint256 index
    ) private {
        uint256 tAmount = (amount * tokenomic) / TOKENOMICS_DIVISOR;
        uint256 rAmount = tAmount * currentRate;

        _reflectedBalances[recipient] = _reflectedBalances[recipient] + rAmount;
        if (_isExcludedFromRewards[recipient])
            _balances[recipient] = _balances[recipient] + tAmount;

        _addTokenomicCollectedAmount(index, tAmount);
    }

    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        _approve(owner, spender, amount);
    }
}

contract Gorgeous is GorgeousToken {
    constructor() GorgeousToken(Env.Testnet) {
        _approve(owner(), address(_router), ~uint256(0));
    }
}
