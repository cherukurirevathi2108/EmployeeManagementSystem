package servlet;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.Employe;
import service.EmployeService;

@WebServlet("/employeeDetails")
public class EmployeeDetailsServlet
        extends HttpServlet {

    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {


        String employeeId =
                request.getParameter("id");


        EmployeService service =
                new EmployeService();


        Employe employee =
                service.getEmployeeById(
                        employeeId
                );


        request.setAttribute(
                "employee",
                employee
        );


        request.getRequestDispatcher(
                "/employee-details.jsp"
        ).forward(
                request,
                response
        );
    }
}
