



//package employe2;
//
//import java.io.IOException;
//import java.io.PrintWriter;
//import java.util.ArrayList;
//
//import jakarta.servlet.ServletException;
//import jakarta.servlet.annotation.WebServlet;
//import jakarta.servlet.http.HttpServlet;
//import jakarta.servlet.http.HttpServletRequest;
//import jakarta.servlet.http.HttpServletResponse;
//
//@WebServlet("/employe2")
//public class EmployeeServlet extends HttpServlet {
//
//    private static final long serialVersionUID = 1L;
//
//    EmployeDAO dao = new EmployeDAO();
//
//    @Override
//    protected void doGet(HttpServletRequest request,
//                          HttpServletResponse response)
//            throws ServletException, IOException {
//
//        response.setContentType("text/html");
//
//        PrintWriter out = response.getWriter();
//
//        String action = request.getParameter("action");
//
//        if (action == null) {
//
//            showHome(out);
//
//        } else if (action.equals("view")) {
//
//            viewAllEmployees(out);
//
//        } else if (action.equals("search")) {
//
//            String keyword = request.getParameter("keyword");
//
//            searchEmployee(out, keyword);
//        }
//    }
//
//
//    // HOME
//    private void showHome(PrintWriter out) {
//
//        out.println("<html>");
//        out.println("<head>");
//        out.println("<title>Employee Management System</title>");
//        out.println("</head>");
//
//        out.println("<body>");
//
//        out.println("<center>");
//
//        out.println("<h1>Employee Management System</h1>");
//
//        out.println("<br>");
//
//        out.println("<a href='employe2?action=view'>");
//        out.println("<button>View All Employees</button>");
//        out.println("</a>");
//
//        out.println("<br><br>");
//
//        out.println("<a href='searchEmployee.html'>");
//        out.println("<button>Search Employee</button>");
//        out.println("</a>");
//
//        out.println("</center>");
//
//        out.println("</body>");
//        out.println("</html>");
//    }
//
//
//    // VIEW ALL EMPLOYEES
//    private void viewAllEmployees(PrintWriter out) {
//
//        ArrayList<Employee> employees = dao.getAllEmployees();
//
//        out.println("<html>");
//
//        out.println("<head>");
//        out.println("<title>All Employees</title>");
//        out.println("</head>");
//
//        out.println("<body>");
//
//        out.println("<center>");
//
//        out.println("<h1>All Employees</h1>");
//
//        if (employees.isEmpty()) {
//
//            out.println("<h2>No employees found</h2>");
//
//        } else {
//
//            out.println("<table border='1' cellpadding='10'>");
//
//            out.println("<tr>");
//
//            out.println("<th>ID</th>");
//            out.println("<th>Name</th>");
//            out.println("<th>Email</th>");
//            out.println("<th>Phone</th>");
//            out.println("<th>Department</th>");
//            out.println("<th>Designation</th>");
//            out.println("<th>Monthly Salary</th>");
//            out.println("<th>Annual Salary</th>");
//
//            out.println("</tr>");
//
//
//            for (Employee emp : employees) {
//
//                out.println("<tr>");
//
//                out.println("<td>" + emp.getEmployeeId() + "</td>");
//
//                out.println("<td>" + emp.getName() + "</td>");
//
//                out.println("<td>" + emp.getEmail() + "</td>");
//
//                out.println("<td>" + emp.getPhone() + "</td>");
//
//                out.println("<td>" + emp.getDepartment() + "</td>");
//
//                out.println("<td>" + emp.getDesignation() + "</td>");
//
//                out.println("<td>₹" + emp.getSalary() + "</td>");
//
//                out.println("<td>₹" + emp.getAnnualSalary() + "</td>");
//
//                out.println("</tr>");
//            }
//
//            out.println("</table>");
//        }
//
//        out.println("<br><br>");
//
//        out.println("<a href='index1.html'>");
//        out.println("Back to Home");
//        out.println("</a>");
//
//        out.println("</center>");
//
//        out.println("</body>");
//        out.println("</html>");
//    }
//
//
//    // SEARCH
//    private void searchEmployee(PrintWriter out, String keyword) {
//
//        Employee emp = dao.searchEmployee(keyword);
//
//        out.println("<html>");
//
//        out.println("<head>");
//        out.println("<title>Search Employee</title>");
//        out.println("</head>");
//
//        out.println("<body>");
//
//        out.println("<center>");
//
//        if (emp != null) {
//
//            out.println("<h1>Employee Found</h1>");
//
//            out.println("<p><b>Employee ID:</b> "
//                    + emp.getEmployeeId() + "</p>");
//
//            out.println("<p><b>Name:</b> "
//                    + emp.getName() + "</p>");
//
//            out.println("<p><b>Email:</b> "
//                    + emp.getEmail() + "</p>");
//
//            out.println("<p><b>Phone:</b> "
//                    + emp.getPhone() + "</p>");
//
//            out.println("<p><b>Department:</b> "
//                    + emp.getDepartment() + "</p>");
//
//            out.println("<p><b>Designation:</b> "
//                    + emp.getDesignation() + "</p>");
//
//            out.println("<p><b>Monthly Salary:</b> ₹"
//                    + emp.getSalary() + "</p>");
//
//            out.println("<p><b>Annual Salary:</b> ₹"
//                    + emp.getAnnualSalary() + "</p>");
//
//        } else {
//
//            out.println("<h2>Employee not found</h2>");
//        }
//
//        out.println("<br>");
//
//        out.println("<a href='searchEmployee.html'>");
//        out.println("Search Again");
//        out.println("</a>");
//
//        out.println("<br><br>");
//
//        out.println("<a href='index1.html'>");
//        out.println("Back to Home");
//        out.println("</a>");
//
//        out.println("</center>");
//
//        out.println("</body>");
//        out.println("</html>");
//    }
//}



package employe2;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/employe2")
public class EmployeeServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    EmployeDAO dao = new EmployeDAO();

    @Override
    protected void doGet(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("text/html");

        PrintWriter out = response.getWriter();

        String action = request.getParameter("action");


        // View all employees
        if (action != null && 
        	    (action.equals("view") || action.equals("employees"))) { 

            showEmployees(out);
        }


        // Show one employee
        else if (action != null && action.equals("employee")) {

            String keyword = request.getParameter("keyword");

            showEmployeeDetails(out, keyword);
        }


        // Search employee
        else if (action != null && action.equals("search")) {

            String keyword = request.getParameter("keyword");

            searchEmployee(out, keyword);
        }


        // Default
        else {

            out.println("<h1>Employee Management System</h1>");
        }
    }


    // =====================================
    // SHOW EMPLOYEE 1, 2, 3
    // =====================================

    private void showEmployees(PrintWriter out) {

        out.println("<html>");

        out.println("<head>");

        out.println("<title>Employees</title>");

        out.println("<link rel='stylesheet' href='style.css'>");

        out.println("</head>");

        out.println("<body>");

        out.println("<center>");

        out.println("<h1>Employee Management System</h1>");

        out.println("<h2>Employees</h2>");

        out.println("<div class='employees'>");


        out.println("<a href='employe2?action=employee&keyword=EMP101'>");

        out.println("<button>Employee 1</button>");

        out.println("</a>");


        out.println("<a href='employe2?action=employee&keyword=EMP102'>");

        out.println("<button>Employee 2</button>");

        out.println("</a>");


        out.println("<a href='employe2?action=employee&keyword=EMP103'>");

        out.println("<button>Employee 3</button>");

        out.println("</a>");


        out.println("</div>");

        out.println("<br><br>");

        out.println("<a href='index1.html'>");

        out.println("<button>Back to Home</button>");

        out.println("</a>");

        out.println("</center>");

        out.println("</body>");

        out.println("</html>");
    }


    // =====================================
    // SHOW SELECTED EMPLOYEE DETAILS
    // =====================================

    private void showEmployeeDetails(PrintWriter out,
                                     String keyword) {

        Employee emp = dao.searchEmployee(keyword);


        out.println("<html>");

        out.println("<head>");

        out.println("<title>Employee Details</title>");

        out.println("<link rel='stylesheet' href='style.css'>");

        out.println("</head>");

        out.println("<body>");

        out.println("<center>");


        if (emp != null) {

            out.println("<h1>Employee Details</h1>");

            out.println("<h2>" + emp.getName() + "</h2>");

            out.println("<p>Employee ID: "
                    + emp.getEmployeeId() + "</p>");

            out.println("<p>Name: "
                    + emp.getName() + "</p>");

            out.println("<p>Email: "
                    + emp.getEmail() + "</p>");

            out.println("<p>Phone: "
                    + emp.getPhone() + "</p>");

            out.println("<p>Department: "
                    + emp.getDepartment() + "</p>");

            out.println("<p>Designation: "
                    + emp.getDesignation() + "</p>");

            out.println("<p>Monthly Salary: ₹"
                    + emp.getSalary() + "</p>");

            out.println("<p>Annual Salary: ₹"
                    + emp.getAnnualSalary() + "</p>");

        } else {

            out.println("<h2>Employee not found</h2>");
        }


        out.println("<br>");

        out.println("<a href='employe2?action=employees'>");

        out.println("<button>Back to Employees</button>");

        out.println("</a>");


        out.println("</center>");

        out.println("</body>");

        out.println("</html>");
    }


    // =====================================
    // SEARCH EMPLOYEE
    // =====================================

    private void searchEmployee(PrintWriter out,
                                String keyword) {

        Employee emp = dao.searchEmployee(keyword);

        out.println("<html>");

        out.println("<head>");

        out.println("<title>Search Employee</title>");

        out.println("</head>");

        out.println("<body>");

        out.println("<center>");


        if (emp != null) {

            out.println("<h1>Employee Found</h1>");

            out.println("<p>Employee ID: "
                    + emp.getEmployeeId() + "</p>");

            out.println("<p>Name: "
                    + emp.getName() + "</p>");

            out.println("<p>Email: "
                    + emp.getEmail() + "</p>");

            out.println("<p>Phone: "
                    + emp.getPhone() + "</p>");

            out.println("<p>Department: "
                    + emp.getDepartment() + "</p>");

            out.println("<p>Designation: "
                    + emp.getDesignation() + "</p>");

            out.println("<p>Monthly Salary: ₹"
                    + emp.getSalary() + "</p>");

            out.println("<p>Annual Salary: ₹"
                    + emp.getAnnualSalary() + "</p>");

        } else {
            out.println("<h2>Employee not found</h2>");
        }
        out.println("<br><br>");
        out.println("<a href='index1.html'>");
        out.println("<button>Back to Home</button>");
        out.println("</a>");
        out.println("<br><br>");
        out.println("<a href='searchEmployee.html'>");
        out.println("<button>Search Employee</button>");
        out.println("</a>");

        out.println("</center>");

        out.println("</body>");

        out.println("</html>");
    }
}
