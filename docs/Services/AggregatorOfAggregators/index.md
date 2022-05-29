# Aggregator Of Aggregators - intro
By calling other aggregator's api just as a normal user does in a browser, we can find the best quote between different aggregators.
This helps users to chose the best possible result at any given time.

It's just like as if user, enter the desired tokens to the aggregator and then after confirm the price; swapped on the recommended aggregator.


### Normal Flow
Let's say user want to test out if is it good enough to use 1inch aggregator or not.
And if not, check the quotes on another aggregator . 
```mermaid
graph LR
    A[User] -->|Quote| B([Aggregator-UI])
    B --> C{Is quote good enough}
    C -->|Yes| D[Swap]
    C -->|No| E[Check another aggregator]
    E -.->|Goes Back|B
```
### Agg Of Agg Flow
However, in this service user will experience a flow as shown in following chart: 

```mermaid
flowchart LR
    A[User] -->|Quote| B([Timechainswap-UI])
    B --- C([Receive Best Quote])
    C -->|Chosen Aggregator| D[Swap request]
    D --> |Send swap object| A
```
And What Happens in the Back-end side is one:

- Quoting for user request
```mermaid
flowchart LR
    C([Receive Best Quote]) -.- Server([Server])
    Server --> Z([Call network's aggregators quote endpoint])
    Z -.-> OneInch(1inch)
    Z -.-> OC(OpenOcean)
    Z -.-> Ky(KyberSwap)
    Ky ---> |Result| Res(Aggregator Quote)
    OC --> |Result| Res
    OneInch --> |Result| Res
    Res -.-> |Best Quote|Server

```
- Creating a swap object for user
```mermaid
flowchart LR
    C([Create Swap object]) -.- Server([Server])
    Server --> Z([Call network's aggregators swap endopint])
    Z ==> Co(Chosen aggregator)
    Co --> AggRes(parse response)
    AggRes --> X{Estimate Gas}
    X --> |Success| Res(Aggregator Swap Response)
    X --> |Failed| G(Next Best Aggregator)
    G --> |Try Next Aggregator| AggRes
    Res -.-> |Swap Object|Server
    G --> |Tried all network aggregator| No(Error)
    No -.->|Error Response| Server
```
