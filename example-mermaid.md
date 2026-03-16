# Mermaid Diagram Examples

A showcase of various Mermaid diagram types rendered to PDF.

## Flowchart

```mermaid
flowchart TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great!]
    B -->|No| D[Debug]
    D --> E[Check logs]
    E --> B
    C --> F[Deploy]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant API
    participant DB

    User->>API: POST /login
    API->>DB: Query user
    DB-->>API: User record
    API-->>User: JWT token
    User->>API: GET /data (with token)
    API->>DB: Fetch data
    DB-->>API: Results
    API-->>User: JSON response
```

## Class Diagram

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound()
    }
    class Dog {
        +String breed
        +fetch()
    }
    class Cat {
        +bool indoor
        +purr()
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review : Submit
    Review --> Approved : Approve
    Review --> Draft : Request changes
    Approved --> Published : Publish
    Published --> [*]
```

## Gantt Chart

```mermaid
gantt
    title Project Timeline
    dateFormat  YYYY-MM-DD
    section Design
    Wireframes       :done, d1, 2026-01-01, 10d
    Mockups          :done, d2, after d1, 7d
    section Development
    Backend API      :active, dev1, 2026-01-18, 14d
    Frontend UI      :dev2, after dev1, 14d
    section Testing
    Integration tests :test1, after dev2, 7d
```

## Pie Chart

```mermaid
pie title Language Distribution
    "TypeScript" : 45
    "Python" : 30
    "Go" : 15
    "Other" : 10
```

## Entity Relationship Diagram

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "ordered in"
    USER {
        int id PK
        string name
        string email
    }
    ORDER {
        int id PK
        date created_at
        string status
    }
    PRODUCT {
        int id PK
        string name
        float price
    }
```
