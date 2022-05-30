# Two - 2 

Here is basic diagram about what happened in aggregator so far.
In this version of aggregator we only had a simple approach.
It collected data via a simple script.

## HLA Diagram 
Setup we used to run services.
List of services we used are as followed:

- Aggregator-api
- Aggregator-worker
- Mongo
- Redis
- Nginx
- RPC-node (Only For Backup)
- RPC-URL

![HLA](Diagrams/Version2.drawio#0)


## Data Flow Diagram
How data flow though service and inter app connections are handled!
Periodic Tasks

![Data Flow](Diagrams/Version2.drawio#1)


### Extra points
Points to Mention :

- This version had no load balancing or user load
- The script that fill the db (A simple .json file) was ran manually
  - In file the file we stored:
    - The addresses to uniswap pairs
    - Tokens uniswap had
    - Connection from pairs to tokens
  - Later a crontab task as added