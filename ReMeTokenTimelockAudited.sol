pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0//contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0//contracts/math/SafeMath.sol";

contract TokenTimelock {
    using SafeMath for uint256;

    IERC20 public token;
    /**
     * @dev maxWithdrawDeposits limits the number of deposits a user can withdraw at once.
     * Prevents releaseMultipleDeposits() to revert with "out of gas".
     */
    uint256 public maxWithdrawDeposits;
    address public msgsender;


    mapping(address => Deposit[]) public beneficiaries;

    struct Deposit {
        uint256 amount;
        uint256 releaseTime;
        bool isClaimed;
    }

    event DepositIssued(
        address beneficiary,
        uint256 amount,
        uint256 releaseTime,
        uint256 index
    );

    event DepositReleased(address beneficiary, uint256 amount, uint256 index);
    event MultipleDepositsReleased(
        address beneficiary,
        uint256 amount,
        uint256 startIndex,
        uint256 endIndex
    );

    constructor(IERC20 _token, uint256 _maxWithdrawDeposits) public {
        require(_maxWithdrawDeposits > 0);
        token = _token;
        maxWithdrawDeposits = _maxWithdrawDeposits;
        msgsender = msg.sender;

    }

    function getAllBeneficiaryDeposits(address _beneficiary)
        public
        view
        returns (Deposit[] memory)
    {
        return beneficiaries[_beneficiary];
    }

    function getBeneficiaryDeposit(address _beneficiary, uint256 _depositId)
        public
        view
        returns (Deposit memory)
    {
        return beneficiaries[_beneficiary][_depositId];
    }

    function getBeneficiaryDepositsCount(address _beneficiary)
        public
        view
        returns (uint256)
    {
        return beneficiaries[_beneficiary].length;
    }

    function getTimestampAfterNDays(uint256 _days)
        public
        view
        returns (uint256)
    {
        return block.timestamp + _days * 1 days;
    }

    /**
     * @param _releaseTime should be the timestamp of the release date in seconds since unix epoch.
     */
    function createDeposit(
        address _beneficiary,
        uint256 _amount,
        uint256 _releaseTime
    ) external {
        token.transferFrom(msg.sender, address(this), _amount);
        addBeneficiary(_beneficiary, _amount, _releaseTime);
    }

    /**
     * The three input arrays must be with equal length and with maximum of a 100 entities.
     */
    function createMultipleDeposits(
        address[] memory _beneficiaries,
        uint256[] memory _amounts,
        uint256[] memory _releaseTimes
    ) public {
        require(
            _beneficiaries.length == _amounts.length &&
                _amounts.length == _releaseTimes.length,
            "Mismatch in array lengths"
        );

        uint256 totalTokensDeposited;

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            addBeneficiary(_beneficiaries[i], _amounts[i], _releaseTimes[i]);
            totalTokensDeposited = totalTokensDeposited.add(_amounts[i]);
        }

        token.transferFrom(msg.sender, address(this), totalTokensDeposited);
    }

    function releaseDeposit(uint256 _depositId) public {
        require(
            beneficiaries[msg.sender].length > _depositId,
            "Non existing deposit id"
        );
        require(
            block.timestamp >=
                beneficiaries[msg.sender][_depositId].releaseTime,
            "TokenTimelock: current time is before release time"
        );
        require(
            !beneficiaries[msg.sender][_depositId].isClaimed,
            "The deposit is already claimed"
        );

        beneficiaries[msg.sender][_depositId].isClaimed = true;

        uint256 amount = beneficiaries[msg.sender][_depositId].amount;
        token.transfer(msg.sender, amount);

        emit DepositReleased(msg.sender, amount, _depositId);
    }

    function releaseMultipleDeposits(uint256 _startIndex, uint256 _endIndex)
        public
    {
        require(_endIndex > _startIndex, "End index is before start index");
        require(
            _endIndex.sub(_startIndex) <= maxWithdrawDeposits,
            "Max withdrawal count exceeded"
        );

        require(
            beneficiaries[msg.sender].length > _endIndex,
            "End Index out of range"
        );

        uint256 totalTokensDeposited;

        for (uint256 i = _startIndex; i <= _endIndex; i++) {
            if (beneficiaries[msg.sender][i].isClaimed) {
                continue;
            }
            if (block.timestamp < beneficiaries[msg.sender][i].releaseTime) {
                continue;
            }
            totalTokensDeposited = totalTokensDeposited.add(
                beneficiaries[msg.sender][i].amount
            );
            beneficiaries[msg.sender][i].isClaimed = true;
        }

        token.transfer(msg.sender, totalTokensDeposited);
        emit MultipleDepositsReleased(
            msg.sender,
            totalTokensDeposited,
            _startIndex,
            _endIndex
        );
    }

    function addBeneficiary(
        address _beneficiary,
        uint256 _amount,
        uint256 _releaseTime
    ) internal {
        require(
            _beneficiary != address(0),
            "Beneficiary address cannot be zero address"
        );

        require(_amount > 0, "Amount cannot be 0");

        require(
            _releaseTime > block.timestamp,
            "TokenTimelock: release time is after current time"
        );
        beneficiaries[_beneficiary].push(
            Deposit({
                amount: _amount,
                releaseTime: _releaseTime,
                isClaimed: false
            })
        );
        emit DepositIssued(
            _beneficiary,
            _amount,
            _releaseTime,
            beneficiaries[_beneficiary].length - 1
        );
    }
}

