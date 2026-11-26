package servlet;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import util.Branding;
import util.Json;

/**
 * Public, read-only: the company name and logo URL for the (static) login page.
 * Nothing secret is exposed here - both values are shown to anyone who opens the login page.
 */
@WebServlet("/branding")
public class BrandingServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("name", Branding.name());
        out.put("logo", Branding.logo());
        res.setContentType("application/json");
        res.setCharacterEncoding("UTF-8");
        res.setHeader("Cache-Control", "no-cache");
        res.getWriter().write(Json.of(out));
    }
}
