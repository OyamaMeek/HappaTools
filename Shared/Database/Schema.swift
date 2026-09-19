enum Schema {
    static let createOperationLogs = """
        CREATE TABLE IF NOT EXISTS operation_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            target_path TEXT NOT NULL,
            commit_message TEXT,
            stdout TEXT,
            stderr TEXT,
            status TEXT NOT NULL,
            created_at REAL NOT NULL DEFAULT (julianday('now'))
        );
        """

    static let createTimestampIndex =
        "CREATE INDEX IF NOT EXISTS idx_timestamp ON operation_logs(timestamp);"
    static let createCreatedAtIndex =
        "CREATE INDEX IF NOT EXISTS idx_created_at ON operation_logs(created_at);"
}
