package com.employee;
import java.sql.Connection;
import java.sql.DriverManager;
public class DBconnection {
    public static void main(String[] args) {
        String url = "jdbc:mysql://localhost:3306/employee_management";
        String username = "root";
        String password = "root";
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection con = DriverManager.getConnection(url, username, password);
            System.out.println("Database connected successfully!");
            con.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}