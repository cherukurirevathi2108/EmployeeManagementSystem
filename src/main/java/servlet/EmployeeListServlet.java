package servlet;

import java.io.IOException;
import java.util.ArrayList;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.Employe;
import service.EmployeService;

@WebServlet("/employees")
public class EmployeeListServlet
        extends HttpServlet {

    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {


        EmployeService service =
                new EmployeService();


        ArrayList<Employe> employees =
                service.getAllEmployees();


        request.setAttribute(
                "employees",
                employees
        );


        request.getRequestDispatcher(
                "/employee-list.jsp"
        ).forward(
                request,
                response
        );
    }
}