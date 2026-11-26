package service;

import java.util.ArrayList;

import DAO.EmployeDAO;
import model.Employe;

public class EmployeService {

    private EmployeDAO employeDAO;

    public EmployeService() {
        employeDAO = new EmployeDAO();
    }

    // GET ALL EMPLOYEES
    public ArrayList<Employe> getAllEmployees() {
        return employeDAO.getAllEmployees();
    }

    // SEARCH EMPLOYEES
    public ArrayList<Employe> searchEmployees(String keyword) {
        return employeDAO.searchEmployees(keyword);
    }

    // GET EMPLOYEE BY ID
    public Employe getEmployeeById(String employeeId) {
        return employeDAO.getEmployeeById(employeeId);
    }

    // ADD EMPLOYEE
    public boolean addEmployee(Employe employee) {
        return employeDAO.addEmployee(employee);
    }

    // AUTO GENERATE EMPLOYEE ID
    public String generateEmployeeId() {
        return employeDAO.generateEmployeeId();
    }
}