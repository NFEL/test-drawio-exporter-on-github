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

## Query
A DQL query finds nodes based on search criteria, matches patterns in a graph and returns a graph as a result.

A query is composed of nested blocks, starting with a query root. The root finds the initial set of nodes against which the following graph matching and filtering is applied.

## Facets and Edge Attributes in DQL
Dgraph supports facets — key value pairs on edges — as an extension to RDF triples. That is, facets add properties to edges, rather than to nodes. Facets can also be used as weights for edges. [More about facets.](https://dgraph.io/docs/query-language/facets/)



## Functions with DQL
Dgraph Query Language (DQL) functions allow filtering based on properties of nodes or variables. Functions can be applied in the query root or in filters. [More about fucntions.](https://dgraph.io/docs/query-language/functions/)

**Comparison functions:**
- le: less than or equal to
- lt: less than
- ge: greater than or equal to
- gt: greater than



