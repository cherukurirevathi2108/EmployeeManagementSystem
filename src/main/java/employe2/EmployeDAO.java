//package employe2;
//
//import java.sql.Connection;
//import java.sql.PreparedStatement;
//import java.sql.ResultSet;
//import java.util.ArrayList;
//
//public class EmployeDAO {
//
//    // View all employees
//    public ArrayList<Employee> getAllEmployees() {
//
//        ArrayList<Employee> employees = new ArrayList<>();
//
//        String sql = "SELECT * FROM employee";
//
//        try {
//
//            Connection con = DBconnection.getConnection();
//
//            PreparedStatement ps =
//                    con.prepareStatement(sql);
//
//            ResultSet rs = ps.executeQuery();
//
//            while (rs.next()) {
//
//                Employee emp = new Employee(
//
//                        rs.getString("employee_id"),
//                        rs.getString("name"),
//                        rs.getString("email"),
//                        rs.getString("phone"),
//                        rs.getString("department"),
//                        rs.getString("designation"),
//                        rs.getDouble("salary")
//                );
//
//                employees.add(emp);
//            }
//
//            rs.close();
//            ps.close();
//            con.close();
//
//        } catch (Exception e) {
//
//            e.printStackTrace();
//        }
//
//        return employees;
//    }
//
//
//    // Search employee by ID or Name
//    public Employee searchEmployee(String keyword) {
//
//        Employee emp = null;
//
//        String sql =
//                "SELECT * FROM employee " +
//                "WHERE employee_id = ? OR name = ?";
//
//        try {
//
//            Connection con =
//                    DBconnection.getConnection();
//
//            PreparedStatement ps =
//                    con.prepareStatement(sql);
//
//            ps.setString(1, keyword);
//            ps.setString(2, keyword);
//
//            ResultSet rs =
//                    ps.executeQuery();
//
//            if (rs.next()) {
//
//                emp = new Employee(
//
//                        rs.getString("employee_id"),
//                        rs.getString("name"),
//                        rs.getString("email"),
//                        rs.getString("phone"),
//                        rs.getString("department"),
//                        rs.getString("designation"),
//                        rs.getDouble("salary")
//                );
//            }
//
//            rs.close();
//            ps.close();
//            con.close();
//
//        } catch (Exception e) {
//
//            e.printStackTrace();
//        }
//
//        return emp;
//    }
//}




package employe2;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;

public class EmployeDAO {

    // View all employees
    public ArrayList<Employee> getAllEmployees() {

        ArrayList<Employee> employees = new ArrayList<Employee>();

        String sql = "SELECT * FROM employee";

        try {

            Connection con = DBconnection.getConnection();

            PreparedStatement ps = con.prepareStatement(sql);

            ResultSet rs = ps.executeQuery();

            while (rs.next()) {

                Employee emp = new Employee(
                        rs.getString("employee_id"),
                        rs.getString("name"),
                        rs.getString("email"),
                        rs.getString("phone"),
                        rs.getString("department"),
                        rs.getString("designation"),
                        rs.getDouble("salary")
                );

                employees.add(emp);
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return employees;
    }


    // Search employee by ID or Name
    public Employee searchEmployee(String keyword) {

        Employee emp = null;

        String sql = "SELECT * FROM employee "
                   + "WHERE employee_id = ? OR name = ?";

        try {

            Connection con = DBconnection.getConnection();

            PreparedStatement ps = con.prepareStatement(sql);

            ps.setString(1, keyword);
            ps.setString(2, keyword);

            ResultSet rs = ps.executeQuery();

            if (rs.next()) {

                emp = new Employee(
                        rs.getString("employee_id"),
                        rs.getString("name"),
                        rs.getString("email"),
                        rs.getString("phone"),
                        rs.getString("department"),
                        rs.getString("designation"),
                        rs.getDouble("salary")
                );
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return emp;
    }
}