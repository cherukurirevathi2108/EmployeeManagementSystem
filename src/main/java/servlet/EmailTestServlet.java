package servlet;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import service.EmailService;
@WebServlet("/testEmail")
public class EmailTestServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {
        boolean sent = EmailService.sendCredentials(
                "cherukurirevathi5@gmail.com",
                "Revathi",
                "EMP999",
                "test123",
                "Employee"
        );
        response.setContentType("text/html");

        if (sent) {
            response.getWriter().println(
                "<h2>Email sent successfully!</h2>"
            );
        } else {
            response.getWriter().println(
                "<h2>Email sending failed!</h2>"
            );
        }
    }
}