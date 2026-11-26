package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;

import model.DBcConnection;
import model.Employe;

public class EmployeDAO {

    // =====================================================
    // GET ALL EMPLOYEES
    // =====================================================

    public ArrayList<Employe> getAllEmployees() {

        ArrayList<Employe> employees =
                new ArrayList<>();

        try {

            Connection con =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT * FROM employees " +
                    "WHERE employee_id NOT LIKE 'ADMIN%' " +
                    "ORDER BY employee_id";

            PreparedStatement ps =
                    con.prepareStatement(sql);

            ResultSet rs =
                    ps.executeQuery();

            while (rs.next()) {

                Employe employee =
                        new Employe();

                employee.setEmployeeId(
                        rs.getString("employee_id")
                );

                employee.setName(
                        rs.getString("name")
                );

                employee.setEmail(
                        rs.getString("email")
                );

                employee.setPhone(
                        rs.getString("phone")
                );

                employee.setDepartment(
                        rs.getString("department")
                );

                employee.setDesignation(
                        rs.getString("designation")
                );

                employee.setSalary(
                        rs.getDouble("salary")
                );

                employee.setStatus(
                        rs.getString("status")
                );

                employees.add(employee);
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return employees;
    }


    // =====================================================
    // SEARCH EMPLOYEE BY ID OR NAME
    // =====================================================

    public ArrayList<Employe> searchEmployees(
            String keyword) {

        ArrayList<Employe> employees =
                new ArrayList<>();

        try {

            Connection con =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT * FROM employees " +
                    "WHERE employee_id NOT LIKE 'ADMIN%' " +
                    "AND (employee_id LIKE ? OR name LIKE ?) " +
                    "ORDER BY employee_id";

            PreparedStatement ps =
                    con.prepareStatement(sql);

            String searchValue =
                    "%" + keyword + "%";

            ps.setString(1, searchValue);
            ps.setString(2, searchValue);

            ResultSet rs =
                    ps.executeQuery();

            while (rs.next()) {

                Employe employee =
                        new Employe();

                employee.setEmployeeId(
                        rs.getString("employee_id")
                );

                employee.setName(
                        rs.getString("name")
                );

                employee.setEmail(
                        rs.getString("email")
                );

                employee.setPhone(
                        rs.getString("phone")
                );

                employee.setDepartment(
                        rs.getString("department")
                );

                employee.setDesignation(
                        rs.getString("designation")
                );

                employee.setSalary(
                        rs.getDouble("salary")
                );

                employee.setStatus(
                        rs.getString("status")
                );

                employees.add(employee);
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return employees;
    }


    // =====================================================
    // GET EMPLOYEE BY ID
    // =====================================================

    public Employe getEmployeeById(
            String employeeId) {

        Employe employee = null;

        try {

            Connection con =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT * FROM employees " +
                    "WHERE employee_id = ?";

            PreparedStatement ps =
                    con.prepareStatement(sql);

            ps.setString(1, employeeId);

            ResultSet rs =
                    ps.executeQuery();

            if (rs.next()) {

                employee =
                        new Employe();

                employee.setEmployeeId(
                        rs.getString("employee_id")
                );

                employee.setName(
                        rs.getString("name")
                );

                employee.setEmail(
                        rs.getString("email")
                );

                employee.setPhone(
                        rs.getString("phone")
                );

                employee.setDepartment(
                        rs.getString("department")
                );

                employee.setDesignation(
                        rs.getString("designation")
                );

                employee.setSalary(
                        rs.getDouble("salary")
                );

                employee.setStatus(
                        rs.getString("status")
                );
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return employee;
    }


    // =====================================================
    // ADD EMPLOYEE
    // =====================================================

    public boolean addEmployee(
            Employe employee) {

        boolean result = false;

        try {

            Connection con =
                    DBcConnection.getConnection();

            String sql =
                    "INSERT INTO employees " +
                    "(employee_id, name, email, phone, " +
                    "department, designation, salary, status) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            PreparedStatement ps =
                    con.prepareStatement(sql);

            ps.setString(
                    1,
                    employee.getEmployeeId()
            );

            ps.setString(
                    2,
                    employee.getName()
            );

            ps.setString(
                    3,
                    employee.getEmail()
            );

            ps.setString(
                    4,
                    employee.getPhone()
            );

            ps.setString(
                    5,
                    employee.getDepartment()
            );

            ps.setString(
                    6,
                    employee.getDesignation()
            );

            ps.setDouble(
                    7,
                    employee.getSalary()
            );

            ps.setString(
                    8,
                    employee.getStatus()
            );

            int rows =
                    ps.executeUpdate();

            if (rows > 0) {
                result = true;
            }

            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return result;
    }


    // =====================================================
    // AUTO GENERATE EMPLOYEE ID
    // =====================================================

    public String generateEmployeeId() {

        String employeeId =
                "EMP001";

        try {

            Connection con =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT employee_id " +
                    "FROM employees " +
                    "WHERE employee_id LIKE 'EMP%' " +
                    "ORDER BY CAST(" +
                    "SUBSTRING(employee_id, 4) " +
                    "AS UNSIGNED) DESC " +
                    "LIMIT 1";

            PreparedStatement ps =
                    con.prepareStatement(sql);

            ResultSet rs =
                    ps.executeQuery();

            if (rs.next()) {

                String lastId =
                        rs.getString(
                                "employee_id"
                        );

                if (lastId != null &&
                        lastId.startsWith("EMP")) {

                    String numberPart =
                            lastId.substring(3);

                    int number =
                            Integer.parseInt(
                                    numberPart
                            );

                    number++;

                    employeeId =
                            String.format(
                                    "EMP%03d",
                                    number
                            );
                }
            }

            rs.close();
            ps.close();
            con.close();

        } catch (Exception e) {

            e.printStackTrace();
        }

        return employeeId;
    }
}