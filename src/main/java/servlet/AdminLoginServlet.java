package servlet;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/AdminLoginServlet")
public class AdminLoginServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String username =
                request.getParameter("username");

        String password =
                request.getParameter("password");

        if ("admin".equals(username)
                && "admin123".equals(password)) {

            response.sendRedirect("adminPanel.jsp");

        } else {

            response.setContentType("text/html");

            response.getWriter().println(
                "<h3>Invalid Admin Username or Password</h3>"
            );

            response.getWriter().println(
                "<a href='adminLogin.jsp'>Back to Login</a>"
            );
        }
    }
}
