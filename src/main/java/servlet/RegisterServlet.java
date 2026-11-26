package servlet;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.Employe;
import service.EmployeService;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private EmployeService employeService;


    // =====================================================
    // INIT
    // =====================================================

    @Override
    public void init() {

        employeService =
                new EmployeService();
    }


    // =====================================================
    // GET
    // =====================================================

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.getRequestDispatcher(
                "/register.jsp"
        ).forward(
                request,
                response
        );
    }


    // =====================================================
    // POST
    // =====================================================

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {


        String name =
                request.getParameter("name");

        String email =
                request.getParameter("email");

        String phone =
                request.getParameter("phone");

        String department =
                request.getParameter("department");

        String designation =
                request.getParameter("designation");

        String salaryText =
                request.getParameter("salary");

        String password =
                request.getParameter("password");

        String confirmPassword =
                request.getParameter(
                        "confirmPassword"
                );


        // =================================================
        // PASSWORD CHECK
        // =================================================

        if (password == null ||
                !password.equals(confirmPassword)) {

            request.setAttribute(
                    "error",
                    "Passwords do not match."
            );

            request.getRequestDispatcher(
                    "/register.jsp"
            ).forward(
                    request,
                    response
            );

            return;
        }


        try {

            // =================================================
            // GENERATE EMPLOYEE ID
            // =================================================

            String employeeId =
                    employeService
                            .generateEmployeeId();


            // =================================================
            // CREATE EMPLOYEE
            // =================================================

            Employe employee =
                    new Employe();


            employee.setEmployeeId(
                    employeeId
            );


            employee.setName(
                    name
            );


            employee.setEmail(
                    email
            );


            employee.setPhone(
                    phone
            );


            employee.setDepartment(
                    department
            );


            employee.setDesignation(
                    designation
            );


            double salary =
                    Double.parseDouble(
                            salaryText
                    );


            employee.setSalary(
                    salary
            );


            // New employee status

            employee.setStatus(
                    "ACTIVE"
            );


            // =================================================
            // SAVE EMPLOYEE
            // =================================================

            boolean employeeAdded =
                    employeService.addEmployee(
                            employee
                    );


            if (employeeAdded) {

                // =============================================
                // SUCCESS
                // =============================================

                request.setAttribute(
                        "success",
                        "Employee registered successfully!"
                );


                request.setAttribute(
                        "employeeId",
                        employeeId
                );


                request.getRequestDispatcher(
                        "/register.jsp"
                ).forward(
                        request,
                        response
                );


                return;

            } else {

                request.setAttribute(
                        "error",
                        "Employee registration failed."
                );

            }


        } catch (Exception e) {

            e.printStackTrace();

            request.setAttribute(
                    "error",
                    "Something went wrong during registration."
            );
        }


        // =================================================
        // SHOW SAME PAGE
        // =================================================

        request.getRequestDispatcher(
                "/register.jsp"
        ).forward(
                request,
                response
        );
    }
}