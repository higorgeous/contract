// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./Presaleable.sol";
import "./Tokenomics.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IPancakeV2Factory.sol";
import "../interfaces/IPancakeV2Router.sol";
import "../libraries/Address.sol";
import "../utilities/Ownable.sol";

abstract contract BaseRedistribution is
    Presaleable,
    Tokenomics,
    IERC20,
    IERC20Metadata,
    Ownable
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
        uint256 tTotalTokenomics = tAmount * tokenomicsSum / TOKENOMICS_DIVISOR;
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
