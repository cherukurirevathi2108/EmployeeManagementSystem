package model;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DBcConnection {

    private static final String URL =
            "jdbc:mysql://localhost:3306/employee_db";
    private static final String USER =
            "root";

    private static final String PASSWORD =
            "root";

    public static String getUrl() { return URL; }
    public static String getUser() { return USER; }
    public static String getPassword() { return PASSWORD; }

    public static Connection getConnection() {

        Connection connection = null;

        try {

            Class.forName("com.mysql.cj.jdbc.Driver");

            connection = DriverManager.getConnection(
                    URL,
                    USER,
                    PASSWORD
            );

            System.out.println("Database connected successfully");

        } catch (ClassNotFoundException e) {

            e.printStackTrace();

        } catch (SQLException e) {

            e.printStackTrace();
        }

        return connection;
    }
}
