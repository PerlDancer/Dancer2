CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR NOT NULL UNIQUE,
    password VARCHAR NOT NULL
);

INSERT INTO users (username, password)
VALUES ('admin', '$argon2id$v=19$m=262144,t=3,p=1$07krd3DaNn3b9JplNPSjnA$CiFKqjqgecDiYoV0qq0QsZn2GXmORkia2YIhgn/dbBo'); -- admin/test
