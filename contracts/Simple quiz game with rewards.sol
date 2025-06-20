// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Simple Quiz Game with Rewards
 * @dev A decentralized quiz game where players can answer questions and earn ETH rewards
 * @author Quiz Game Developer
 */
contract QuizGame {
    // State variables
    address public owner;
    uint256 public rewardPool;
    uint256 public questionCounter;
    uint256 public constant REWARD_AMOUNT = 0.01 ether;
    
    // Structs
    struct Question {
        string questionText;
        string[] options;
        uint256 correctAnswer; // Index of correct answer (0-3)
        bool isActive;
        uint256 reward;
    }
    
    struct Player {
        uint256 totalRewards;
        uint256 questionsAnswered;
        uint256 correctAnswers;
        mapping(uint256 => bool) hasAnswered;
    }
    
    // Mappings
    mapping(uint256 => Question) public questions;
    mapping(address => Player) public players;
    
    // Events
    event QuestionAdded(uint256 indexed questionId, string questionText, uint256 reward);
    event QuestionAnswered(address indexed player, uint256 indexed questionId, bool correct, uint256 reward);
    event RewardClaimed(address indexed player, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier questionExists(uint256 _questionId) {
        require(_questionId < questionCounter, "Question does not exist");
        require(questions[_questionId].isActive, "Question is not active");
        _;
    }
    
    modifier hasNotAnswered(uint256 _questionId) {
        require(!players[msg.sender].hasAnswered[_questionId], "Already answered this question");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        questionCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Add a new quiz question (only owner)
     * @param _questionText The question text
     * @param _options Array of 4 answer options
     * @param _correctAnswer Index of correct answer (0-3)
     */
    function addQuestion(
        string memory _questionText,
        string[4] memory _options,
        uint256 _correctAnswer
    ) external onlyOwner {
        require(_correctAnswer < 4, "Correct answer index must be 0-3");
        require(bytes(_questionText).length > 0, "Question text cannot be empty");
        
        // Convert fixed array to dynamic array for storage
        string[] memory optionsArray = new string[](4);
        for (uint i = 0; i < 4; i++) {
            require(bytes(_options[i]).length > 0, "Option cannot be empty");
            optionsArray[i] = _options[i];
        }
        
        questions[questionCounter] = Question({
            questionText: _questionText,
            options: optionsArray,
            correctAnswer: _correctAnswer,
            isActive: true,
            reward: REWARD_AMOUNT
        });
        
        emit QuestionAdded(questionCounter, _questionText, REWARD_AMOUNT);
        questionCounter++;
    }
    
    /**
     * @dev Core Function 2: Answer a quiz question
     * @param _questionId ID of the question to answer
     * @param _answer Player's answer (0-3)
     */
    function answerQuestion(uint256 _questionId, uint256 _answer) 
        external 
        questionExists(_questionId) 
        hasNotAnswered(_questionId) 
    {
        require(_answer < 4, "Answer must be 0-3");
        require(rewardPool >= REWARD_AMOUNT, "Insufficient reward pool");
        
        Question storage question = questions[_questionId];
        Player storage player = players[msg.sender];
        
        // Mark as answered
        player.hasAnswered[_questionId] = true;
        player.questionsAnswered++;
        
        bool isCorrect = (_answer == question.correctAnswer);
        uint256 rewardAmount = 0;
        
        if (isCorrect) {
            player.correctAnswers++;
            player.totalRewards += REWARD_AMOUNT;
            rewardAmount = REWARD_AMOUNT;
            rewardPool -= REWARD_AMOUNT;
        }
        
        emit QuestionAnswered(msg.sender, _questionId, isCorrect, rewardAmount);
    }
    
    /**
     * @dev Core Function 3: Claim accumulated rewards
     */
    function claimRewards() external {
        Player storage player = players[msg.sender];
        uint256 rewardAmount = player.totalRewards;
        
        require(rewardAmount > 0, "No rewards to claim");
        require(address(this).balance >= rewardAmount, "Contract has insufficient funds");
        
        // Reset player rewards
        player.totalRewards = 0;
        
        // Transfer rewards
        payable(msg.sender).transfer(rewardAmount);
        
        emit RewardClaimed(msg.sender, rewardAmount);
    }
    
    // Additional utility functions
    
    /**
     * @dev Get question details
     * @param _questionId ID of the question
     * @return questionText The question text
     * @return options Array of answer options
     * @return isActive Whether question is active
     * @return reward Reward amount for correct answer
     */
    function getQuestion(uint256 _questionId) 
        external 
        view 
        questionExists(_questionId)
        returns (
            string memory questionText,
            string[] memory options,
            bool isActive,
            uint256 reward
        ) 
    {
        Question storage question = questions[_questionId];
        return (
            question.questionText,
            question.options,
            question.isActive,
            question.reward
        );
    }
    
    /**
     * @dev Get player statistics
     * @param _player Address of the player
     * @return totalRewards Unclaimed rewards
     * @return questionsAnswered Total questions answered
     * @return correctAnswers Total correct answers
     */
    function getPlayerStats(address _player) 
        external 
        view 
        returns (
            uint256 totalRewards,
            uint256 questionsAnswered,
            uint256 correctAnswers
        ) 
    {
        Player storage player = players[_player];
        return (
            player.totalRewards,
            player.questionsAnswered,
            player.correctAnswers
        );
    }
    
    /**
     * @dev Check if player has answered a specific question
     * @param _player Address of the player
     * @param _questionId ID of the question
     * @return hasAnswered Whether player has answered the question
     */
    function hasPlayerAnswered(address _player, uint256 _questionId) 
        external 
        view 
        returns (bool hasAnswered) 
    {
        return players[_player].hasAnswered[_questionId];
    }
    
    /**
     * @dev Deposit funds to reward pool (anyone can contribute)
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Must send some ETH");
        rewardPool += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Deactivate a question (only owner)
     * @param _questionId ID of the question to deactivate
     */
    function deactivateQuestion(uint256 _questionId) external onlyOwner {
        require(_questionId < questionCounter, "Question does not exist");
        questions[_questionId].isActive = false;
    }
    
    /**
     * @dev Emergency withdraw (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Get total number of questions
     */
    function getTotalQuestions() external view returns (uint256) {
        return questionCounter;
    }
    
    // Fallback function to receive ETH
    receive() external payable {
        rewardPool += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
}
