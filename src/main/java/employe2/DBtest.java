package employe2;

import java.sql.Connection;

public class DBtest {

    public static void main(String[] args) {

        Connection con = DBconnection.getConnection();

        if (con != null) {

            System.out.println("Database Connected Successfully");

        } else {

            System.out.println("Database Connection Failed");
        }
    }
}