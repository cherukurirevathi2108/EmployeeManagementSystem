package com.employee;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
@WebServlet("/employeeiod")
public class EmployeeServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private ArrayList<Employe> employees = new ArrayList<>();
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");
        if ("view".equals(action)) {
            viewEmployees(response);
        }
        else if ("update".equals(action)) {
            showUpdateForm(response);
        }
        else if ("delete".equals(action)) {
            showDeleteForm(response);
        }
        else if ("exit".equals(action)) {
            exit(response);
        }
        else {
            response.sendRedirect("index.html");
        }
    }
    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {
        String action = request.getParameter("action");
        if ("add".equals(action)) {
            addEmployee(request, response);
        }
        else if ("update".equals(action)) {
            updateEmployee(request, response);
        }
        else if ("delete".equals(action)) {
            deleteEmployee(request, response);
        }
    }
    // ADD EMPLOYEE
    private void addEmployee(HttpServletRequest request,
                             HttpServletResponse response)
            throws IOException {
        String employeeId = request.getParameter("employeeId");
        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");
        String department = request.getParameter("department");
        String designation = request.getParameter("designation");
        String salaryText = request.getParameter("salary");
        if (employeeId == null || employeeId.trim().isEmpty()) {
            sendMessage(response, "Employee ID cannot be empty.");
            return;
        }
        if (name == null || name.trim().isEmpty()) {
            sendMessage(response, "Name cannot be empty.");
            return;
        }
        if (email == null || email.trim().isEmpty()) {
            sendMessage(response, "Email cannot be empty.");
            return;
        }

        if (phone == null || !phone.matches("\\d+")) {
            sendMessage(response, "Phone must contain only digits.");
            return;
        }
        double salary;
        try {
            salary = Double.parseDouble(salaryText);
            if (salary <= 0) {
                sendMessage(response, "Salary must be greater than 0.");
                return;
            }
        } catch (Exception e) {
            sendMessage(response, "Enter a valid salary.");
            return;
        }
        Employe employee = new Employe(
                employeeId,
                name,
                email,
                phone,
                department,
                designation,
                salary
        );
        employees.add(employee);
        sendMessage(response, "Employee added successfully.");
    }
    // VIEW EMPLOYEES
    private void viewEmployees(HttpServletResponse response)
            throws IOException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("<html>");
        out.println("<head><title>View Employees</title></head>");
        out.println("<body>");
        out.println("<h1>EMPLOYEE MANAGEMENT SYSTEM</h1>");
        out.println("<h2>Employee Details</h2>");
        if (employees.isEmpty()) {
            out.println("<h3>No employees found.</h3>");
        } else {
            for (Employe employee : employees) {
                out.println("<hr>");
                out.println("Employee ID : "
                        + employee.getEmployeeId() + "<br>");
                out.println("Name : "
                        + employee.getName() + "<br>");
                out.println("Email : "
                        + employee.getEmail() + "<br>");
                out.println("Phone : "
                        + employee.getPhone() + "<br>");
                out.println("Department : "
                        + employee.getDepartment() + "<br>");
                out.println("Designation : "
                        + employee.getDesignation() + "<br>");

                out.println("Salary : ₹"
                        + employee.getSalary() + "<br>");
            }
        }

        out.println("<br><br>");
        out.println("<a href='index.html'>Back to Home</a>");

        out.println("</body>");
        out.println("</html>");
    }

    // SHOW UPDATE FORM
    private void showUpdateForm(HttpServletResponse response)
            throws IOException {

        response.setContentType("text/html");

        PrintWriter out = response.getWriter();

        out.println("<html>");
        out.println("<head><title>Update Employee</title></head>");
        out.println("<body>");

        out.println("<h1>Update Employee</h1>");

        out.println("<form action='employee' method='post'>");

        out.println("<input type='hidden' name='action' value='update'>");

        out.println("Employee ID: ");
        out.println("<input type='text' name='employeeId'><br><br>");

        out.println("New Name: ");
        out.println("<input type='text' name='name'><br><br>");

        out.println("New Email: ");
        out.println("<input type='text' name='email'><br><br>");

        out.println("New Phone: ");
        out.println("<input type='text' name='phone'><br><br>");

        out.println("New Department: ");
        out.println("<input type='text' name='department'><br><br>");

        out.println("New Designation: ");
        out.println("<input type='text' name='designation'><br><br>");

        out.println("New Salary: ");
        out.println("<input type='text' name='salary'><br><br>");

        out.println("<input type='submit' value='Update Employee'>");

        out.println("</form>");

        out.println("<br>");
        out.println("<a href='index.html'>Back to Home</a>");

        out.println("</body>");
        out.println("</html>");
    }

    // UPDATE EMPLOYEE
    private void updateEmployee(HttpServletRequest request,
                                HttpServletResponse response)
            throws IOException {

        String employeeId = request.getParameter("employeeId");

        for (Employe employee : employees) {

            if (employee.getEmployeeId().equals(employeeId)) {

                employee.setName(request.getParameter("name"));
                employee.setEmail(request.getParameter("email"));
                employee.setPhone(request.getParameter("phone"));
                employee.setDepartment(request.getParameter("department"));
                employee.setDesignation(request.getParameter("designation"));

                double salary =
                        Double.parseDouble(request.getParameter("salary"));

                employee.setSalary(salary);

                sendMessage(response,
                        "Employee updated successfully.");

                return;
            }
        }

        sendMessage(response, "Employee ID not found.");
    }

    // SHOW DELETE FORM
    private void showDeleteForm(HttpServletResponse response)
            throws IOException {

        response.setContentType("text/html");

        PrintWriter out = response.getWriter();

        out.println("<html>");
        out.println("<head><title>Delete Employee</title></head>");
        out.println("<body>");

        out.println("<h1>Delete Employee</h1>");

        out.println("<form action='employee' method='post'>");

        out.println("<input type='hidden' name='action' value='delete'>");

        out.println("Employee ID: ");
        out.println("<input type='text' name='employeeId'>");

        out.println("<br><br>");

        out.println("<input type='submit' value='Delete Employee'>");

        out.println("</form>");

        out.println("<br>");
        out.println("<a href='index.html'>Back to Home</a>");

        out.println("</body>");
        out.println("</html>");
    }

    // DELETE EMPLOYEE
    private void deleteEmployee(HttpServletRequest request,
                                HttpServletResponse response)
            throws IOException {

        String employeeId = request.getParameter("employeeId");

        for (Employe employee : employees) {

            if (employee.getEmployeeId().equals(employeeId)) {

                employees.remove(employee);
                sendMessage(response,
                        "Employee deleted successfully.");

                return;
            }
        }

        sendMessage(response, "Employee ID not found.");
    }

    // EXIT
    private void exit(HttpServletResponse response)
            throws IOException {

        response.setContentType("text/html");

        PrintWriter out = response.getWriter();

        out.println("<html>");
        out.println("<body>");

        out.println("<h1>Thank You!</h1>");
        out.println("<h3>Employee Management System Closed.</h3>");

        out.println("</body>");
        out.println("</html>");
    }

    // MESSAGE
    private void sendMessage(HttpServletResponse response,
                             String message)
            throws IOException {

        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("<html>");
        out.println("<body>");

        out.println("<h2>" + message + "</h2>");

        out.println("<br>");
        out.println("<a href='index.html'>Back to Home</a>");

        out.println("</body>");
        out.println("</html>");
    }
}