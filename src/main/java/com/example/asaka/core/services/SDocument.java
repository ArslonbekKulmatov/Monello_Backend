package com.example.asaka.core.services;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.openxml4j.exceptions.InvalidFormatException;
import org.apache.poi.openxml4j.opc.OPCPackage;
import org.apache.poi.openxml4j.opc.PackagePart;
import org.apache.poi.util.Units;
import org.apache.poi.xwpf.usermodel.*;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
@EnableAsync
public class SDocument {

  @Autowired
  private JdbcTemplate jdbcTemplate;

  public String generateDocument(String params) {
    JSONObject response = new JSONObject();
    try {
      JSONObject payload = new JSONObject(params);
      String documentId = payload.getString("id");
      String qrcode = payload.optString("qrcode");

      String template = jdbcTemplate.queryForObject("select file_docx from core_file_templates where id = ?", String.class, documentId);

      byte[] templateBytes = Base64.getDecoder().decode(template);

      Map<String, String> map = new HashMap<>();
      JSONArray variables = payload.getJSONArray("variables");
      for (int i = 0; i < variables.length(); i++) {
        JSONObject variable = variables.getJSONObject(i);
        String name = variable.optString("name");
        Object valueObj = variable.opt("value");
        String value = (valueObj == null) ? "" : String.valueOf(valueObj);
        map.put(name, value);
      }

      byte[] modifiedDocument = replaceAll(templateBytes, map, qrcode);
      String document64 = Base64.getEncoder().encodeToString(modifiedDocument);

      response.put("success", true);
      response.put("document", document64);
    } catch (Exception e) {
      response.put("success", false);
      response.put("error", "Error in generating document: " + e.getMessage());
    }
    return response.toString();
  }

  private byte[] replaceAll(byte[] inputDocx, Map<String, String> variables, String qrcode) {
    try (OPCPackage pkg = OPCPackage.open(new ByteArrayInputStream(inputDocx))) {

      replaceAllXml(pkg, variables);

      try (XWPFDocument doc = new XWPFDocument(pkg)) {
        if (qrcode != null && !qrcode.isEmpty()) {
          BufferedImage qr = generateQr(qrcode);
          addQr(doc, qr);
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        doc.write(out);
        return out.toByteArray();
      }
    } catch (Exception e) {
      throw new RuntimeException("DOCX manipulation failed", e);
    }
  }

  private void replaceAllXml(OPCPackage pkg, Map<String, String> vars) throws IOException, InvalidFormatException {
    for (PackagePart part : pkg.getParts()) {
      String path = part.getPartName().getName();
      String ct = part.getContentType();
      if (!path.startsWith("/word/") || ct == null || !ct.contains("xml")) continue;

      try (InputStream is = part.getInputStream()) {
        String xml = new String(is.readAllBytes(), StandardCharsets.UTF_8);
        String mod = xml;

        // Light pass
        for (var e : vars.entrySet()) {
          String token = "{{" + e.getKey() + "}}";
          Pattern p = buildTokentPatternXml(token);
          mod = p.matcher(mod).replaceAll(Matcher.quoteReplacement(token));
        }
        // Plain pass
        for (var e : vars.entrySet()) {
          String token = "{{" + e.getKey() + "}}";
          String val = e.getValue() == null ? "" : e.getValue();
          mod = mod.replace(token, val);
        }
        // Brutal pass (unconditional)
        for (var e : vars.entrySet()) {
          Pattern ultra = buildTokenPattern(e.getKey());
          String val = e.getValue() == null ? "" : e.getValue();
          mod = ultra.matcher(mod).replaceAll(Matcher.quoteReplacement(val));
        }

        if (!mod.equals(xml)) {
          try (OutputStream os = part.getOutputStream()) {
            os.write(mod.getBytes(StandardCharsets.UTF_8));
          }
        }
      }
    }
  }

  private static Pattern buildTokenPattern(String varName) {
    String any = "(?:\\s|<[^>]+>|&[^;]+;)*"; // spaces, tags, entities
    String open = "\\{" + "\\{"; // {{
    String close = "}" + "}"; // }}
    // {{  <tags> n a m e  }}
    String nameChars = Pattern.quote(varName)
      .chars()
      .mapToObj(c -> String.valueOf((char) c))
      .map(ch -> Pattern.quote(ch) + any)
      .reduce("", String::concat);
    String pattern = open + any + nameChars + any + close;
    return Pattern.compile(pattern, Pattern.DOTALL);
  }

  private static Pattern buildTokentPatternXml(String token) {
    String anyTags = "(?:\\s|<[^>]+>)*"; // spaces or ANY xml tags
    StringBuilder sb = new StringBuilder();
    sb.append(Pattern.quote(String.valueOf(token.charAt(0))));
    for (int i = 1; i < token.length(); i++) {
      sb.append(anyTags).append(Pattern.quote(String.valueOf(token.charAt(i))));
    }
    return Pattern.compile(sb.toString());
  }

  private BufferedImage generateQr(String data) {
    try {
      int qrSize = 150;
      int framePadding = 10;
      int frameWidth = qrSize + 2 * framePadding;
      int frameHeight = qrSize + 2 * framePadding;

      BitMatrix matrix = new MultiFormatWriter().encode(data, BarcodeFormat.QR_CODE, qrSize, qrSize);
      BufferedImage qrImage = MatrixToImageWriter.toBufferedImage(matrix);

      BufferedImage framedQrImage = new BufferedImage(frameWidth, frameHeight, BufferedImage.TYPE_INT_ARGB);
      Graphics2D g = framedQrImage.createGraphics();

      g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
      g.setColor(Color.BLACK);
      g.setStroke(new BasicStroke(2));
      g.drawRect(0, 0, frameWidth - 1, frameHeight - 1);
      g.drawImage(qrImage, framePadding, framePadding, null);
      g.dispose();

      return framedQrImage;
    } catch (Exception e) {
      throw new RuntimeException("Framed QR code generation failed", e);
    }
  }

  private void addQr(XWPFDocument document, BufferedImage qrCodeImage) {
    try {
      boolean qrCodeReplaced = false;

      for (XWPFParagraph paragraph : document.getParagraphs()) {
        for (XWPFRun run : paragraph.getRuns()) {
          String text = run.getText(0);
          if (text != null && text.contains("{{qrcode}}")) {
            run.setText("", 0);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(qrCodeImage, "png", baos);

            try (InputStream qrCodeStream = new ByteArrayInputStream(baos.toByteArray())) {
              run.addPicture(qrCodeStream, Document.PICTURE_TYPE_PNG, "qrcode.png", Units.toEMU(90), Units.toEMU(90));
            }

            qrCodeReplaced = true;
            break;
          }
        }
        if (qrCodeReplaced) break;
      }

      if (!qrCodeReplaced) {
        XWPFParagraph paragraph = document.createParagraph();
        paragraph.setAlignment(ParagraphAlignment.RIGHT);
        XWPFRun run = paragraph.createRun();

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(qrCodeImage, "png", baos);

        try (InputStream qrCodeStream = new ByteArrayInputStream(baos.toByteArray())) {
          run.addPicture(qrCodeStream, Document.PICTURE_TYPE_PNG, "qrcode.png",
            Units.toEMU(90), Units.toEMU(90));
        }
      }

    } catch (Exception e) {
      throw new RuntimeException("Error adding QR code to document", e);
    }
  }
}
