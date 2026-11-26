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

@WebServlet("/searchEmployee")
public class SearchEmployeeServlet
        extends HttpServlet {

    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {


        String search =
                request.getParameter("search");


        EmployeService service =
                new EmployeService();


        ArrayList<Employe> employees =
                service.searchEmployees(
                        search
                );


        request.setAttribute(
                "employees",
                employees
        );


        request.setAttribute(
                "search",
                search
        );


        request.getRequestDispatcher(
                "/search-employee.jsp"
        ).forward(
                request,
                response
        );
    }
}
