package DAO;

import java.sql.Connection;
import java.sql.SQLException;

import model.DBcConnection;
import service.AuditSchema;

/** Connection helper: DBcConnection returns null on failure, we turn that into an exception. */
final class Db {
    private Db() { }

    static Connection open() throws SQLException {
        AuditSchema.ensure();
        Connection c = DBcConnection.getConnection();
        if (c == null) throw new SQLException("Database connection unavailable");
        return c;
    }
}
