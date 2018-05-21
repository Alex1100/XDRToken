//contract launched on rinkeby 0x14ad6d9ff80ebd39c5bb14c1488e79216f927cde

pragma solidity ^0.4.18;
contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant public returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


/*  ERC 20 token */
contract StandardToken is Token {

    function transfer(address _to, uint256 _value) public returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


contract AdvisorTESTToken is StandardToken {
    using SafeMath for uint256;
    // metadata
    string public constant name = "AdvisorTEST Token";
    string public constant symbol = "XDRTEST";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // contracts
    address public ethFundDeposit = 0x09a6737516Ba5cdf9f4FE397Bc31308a7623A2cc;      // deposit address for ETH for Advisor
    address public xdrFundDeposit = 0x09a6737516Ba5cdf9f4FE397Bc31308a7623A2cc;      // deposit address for XDR use and XDR User Fund

    // crowdsale parameters
    bool public isFinalized;  // switched to true in operational state
    uint256 public constant xdrReserve = 500 * (10**6) * 10**decimals;  // 500mm XDR reserved for Advisor Dev/Operations Team
    uint256 public constant tokenExchangeRate = 60400; // 6400 XDR tokens per 1 ETH
    uint256 public constant tokenCreationCap =  8000 * (10**6) * 10**decimals;
    uint256 public constant tokenCreationMin =  675 * (10**6) * 10**decimals;


    // events
    event LogRefund(address indexed _to, uint256 _value);
    event CreateXDR(address indexed _to, uint256 _value);

    // constructor
    constructor ()
    public
    {
      isFinalized = false;  //controls pre through crowdsale state
      totalSupply = xdrReserve;
      balances[xdrFundDeposit] = xdrReserve;  // Deposit XDR share
      emit CreateXDR(xdrFundDeposit, xdrReserve);  // logs XDR fund
    }

    /// @dev Accepts ether and creates new XDR tokens.
    function createTokens() payable external {
      if (isFinalized) revert();
      if (now > 1530403200) revert();
      if (msg.value == 0) revert();

      uint256 tokens = SafeMath.mul(msg.value, tokenExchangeRate); // check that we're not over totals
      uint256 checkedSupply = SafeMath.add(totalSupply, tokens);

      // return money if something goes wrong
      if (tokenCreationCap < checkedSupply) revert();  // odd fractions won't be found

      totalSupply = checkedSupply;
      balances[msg.sender] += tokens;  // safeAdd not needed; bad semantics to use here
      emit CreateXDR(msg.sender, tokens);  // logs token creation
    }

    /// @dev Ends the funding period and sends the ETH home
    function finalize() external {
      if (isFinalized) revert();
      if (msg.sender != ethFundDeposit) revert();  // locks finalize to the ultimate ETH owner
      if(totalSupply < tokenCreationMin) revert();  // have to sell minimum to move to operational
      if(now < 1530403200 && totalSupply != tokenCreationCap) revert();
      // move to operational
      isFinalized = true;
      if(!ethFundDeposit.send(address(this).balance)) revert();  // send the eth to XDR Dev/Operations
    }

    /// @dev Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external {
      if(isFinalized) revert();                       // prevents refund if operational
      if (now > 1530403200) revert(); // prevents refund until sale period is over
      if(totalSupply >= tokenCreationMin) revert();  // no refunds if we sold enough
      if(msg.sender == xdrFundDeposit) revert();    // XDR not entitled to a refund
      uint256 xdrVal = balances[msg.sender];
      if (xdrVal == 0) revert();
      balances[msg.sender] = 0;
      totalSupply = SafeMath.sub(totalSupply, xdrVal); // extra safe
      uint256 ethVal = xdrVal / tokenExchangeRate;  // should be safe; previous throws covers edges
      emit LogRefund(msg.sender, ethVal);  // log it
      if (!msg.sender.send(ethVal)) revert();  // if you're using a contract; make sure it works with .send gas limits
    }

}
