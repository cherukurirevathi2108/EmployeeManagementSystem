
package servlet;

import java.io.IOException;
import java.util.List;
import java.util.Map;

import DAO.ReportDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/reports")
public class ReportServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private final ReportDAO reportDAO = new ReportDAO();

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
            !"ADMIN".equalsIgnoreCase(
                String.valueOf(session.getAttribute("role")))) {

            response.sendRedirect(
                request.getContextPath() + "/login.html");
            return;
        }

        String type = request.getParameter("type");

        if (type == null ||
            !(type.equals("tasks") ||
              type.equals("attendance") ||
              type.equals("leaves") ||
              type.equals("teams"))) {
            type = "tasks";
        }

        try {
            List<Map<String, String>> reportRows =
                reportDAO.getReport(type);

            request.setAttribute("reportRows", reportRows);
            request.setAttribute("reportType", type);
            request.setAttribute("reportError", null);

        } catch (Exception e) {
            getServletContext().log("Unable to load reports", e);

            request.setAttribute(
                "reportRows",
                java.util.Collections.emptyList());

            request.setAttribute("reportType", type);

            request.setAttribute(
                "reportError",
                "Report loading failed. Check the database table columns.");
        }

        request.getRequestDispatcher("/admin_dashbaord.jsp")
               .forward(request, response);
    }
}
