# More on Dgraph
## GraphQL

Dgraph's Generated API.

## DQL

Dgraph's Query Language.

## Pydgraph

The official Dgraph database client implementation for Python. [More about Pydgaph](https://github.com/dgraph-io/pydgraph.)

## DQL Schema and Type System

### [Schema Types](https://dgraph.io/docs/query-language/schema/)

#### Scalar Types

- default

- int

- float

- string

- bool

- dateTime

- geo

- password

#### UID Type

- uid

### [Type System](https://dgraph.io/docs/query-language/type-system/)

Dgraph supports a type system that can be used to categorize nodes and query them based on their type. The type system is also used during expand queries.

example:

type Student {

name

dob

home_address

year

friends

}

Types are declared along with the schema using the Alter endpoint. In order to properly support the above type, a predicate for each of the attributes in the type is also needed, such as:

name: string @index(term) .

dob: datetime .

home_address: string .

year: int .

friends: [uid] .