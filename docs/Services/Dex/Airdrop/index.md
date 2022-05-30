# Airdrop 
For distributing TCS tokens we used the same method uniswap used in their UNI token distribution. [visit link](https://github.com/Uniswap/merkle-distributor)

## Merkel Root
A simple method to validate user data in contract!
For more detailed explanation on this method visit this [link](https://www.javatpoint.com/blockchain-merkle-tree).

## Implementation 
Steps:

* Create Me


The idea behind this method was to calculate the merkle root of many hashed users data to check whether if user is verified to claim or not the requested amount. 

User's detail includes :

* User wallet addresses
* User airdrop amount
* User index (ordered by time they registered for initial airdrop)

Which hash of following values is stored in Mongo Airdrop Database.
