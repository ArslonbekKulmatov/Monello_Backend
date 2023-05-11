package com.example.asaka.core.services;

import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.StringReader;

@Service
public class SEkey {

    //
    public String xmlToJson(String strXml, String tagName) {
        String result = null;
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        DocumentBuilder builder;
        try {
            builder = factory.newDocumentBuilder();
            Document doc = builder.parse(new InputSource(new StringReader(strXml)));
            NodeList nList = doc.getElementsByTagName(tagName);
            for (int i = 0; i < nList.getLength(); i++) {
                Node node = nList.item(i);
                if (node.getNodeType() == Node.ELEMENT_NODE) {
                    result = nList.item(i).getFirstChild().getNodeValue();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return result;
    }

    //Cr By: Uzoqov Abror
    //Метод возвращает список идентификаторов всех пользователей документа PKCS#7
    public String CBRUGetCmsUserIdListStr(JSONObject req) throws JSONException {
        String response;
        JSONObject resp = new JSONObject();
        String cmsresult;
        try {
            String cms = req.getString("cms");
            String url = req.getString("url");
            String xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
                    "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
                    "  <soap:Body>" +
                    "    <CBRUGetCmsUserIdList xmlns=\"http://cbru.org/tcrypt/authsrv\">" +
                    "      <Cms>" + cms + "</Cms>" +
                    "    </CBRUGetCmsUserIdList>" +
                    "  </soap:Body>" +
                    "</soap:Envelope>";
            HttpHeaders headers = new HttpHeaders();
            headers.add("Content-type", "text/xml; charset=utf-8");
            headers.add("Content-Length", String.valueOf(xml.length()));
            RestTemplate rt = new RestTemplate();
            HttpEntity<String> entity = new HttpEntity<>(xml, headers);
            ResponseEntity<String> resEntity = rt.exchange(url, HttpMethod.POST, entity, String.class);
            response = resEntity.getBody();
            cmsresult = xmlToJson(response, "string");
            resp.put("success", true);
            resp.put("cms_userIdList_result", cmsresult);
            resp.put("xml_response", response);
            resp.put("xml_request", xml);
        } catch (Exception e) {
            e.printStackTrace();
            resp.put("success", false);
            resp.put("error", e.getMessage());
        }
        return resp.toString();
    }

    //Cr By: Abror Uzoqov
    //Метод проверяет контейнер PKCS#7
    public String verifyCms(JSONObject req) throws JSONException {
        String response;
        JSONObject resp = new JSONObject();
        String cmsresult;
        try {
            String cms = req.getString("cms");
            String doc_num = req.getString("doc_num");
            String url = req.getString("url");
            String xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
                    "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
                    "  <soap:Body>" +
                    "    <VerifyCms xmlns=\"http://cbru.org/tcrypt/authsrv\">" +
                    "      <cms>" + cms + "</cms>" +
                    "      <docnum>" + doc_num + "</docnum>" +
                    "    </VerifyCms>" +
                    "  </soap:Body>" +
                    "</soap:Envelope>";
            HttpHeaders headers = new HttpHeaders();
            headers.add("Content-type", "text/xml; charset=utf-8");
            headers.add("Content-Length", String.valueOf(xml.length()));
            RestTemplate rt = new RestTemplate();
            HttpEntity<String> entity = new HttpEntity<>(xml, headers);
            ResponseEntity<String> resEntity = rt.exchange(url, HttpMethod.POST, entity, String.class);
            response = resEntity.getBody();
            cmsresult = xmlToJson(response, "VerifyCmsResult");
            resp.put("success", true);
            resp.put("cms_result", Boolean.parseBoolean(cmsresult));
            resp.put("xml_response", response);
            resp.put("xml_request", xml);

        } catch (Exception e) {
            e.printStackTrace();
            resp.put("success", false);
            resp.put("error", e.getMessage());
        }
        return resp.toString();
    }

    //Cr By: Abror Uzoqov
    //Метод возвращает исходное содержимое PKCS#7 документа
    public String GetCmsContent(JSONObject req) throws JSONException {
        String response;
        JSONObject resp = new JSONObject();
        String cmsresult;
        try {
            String cms = req.getString("cms");
            String doc_num = req.getString("doc_num");
            String url = req.getString("url");
            String xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
                    "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
                    "  <soap:Body>" +
                    "    <GetCmsContent xmlns=\"http://cbru.org/tcrypt/authsrv\">" +
                    "      <cms>" + cms + "</cms>" +
                    "      <docnum>" + doc_num + "</docnum>" +
                    "    </GetCmsContent>" +
                    "  </soap:Body>" +
                    "</soap:Envelope>";

            HttpHeaders headers = new HttpHeaders();
            headers.add("Content-type", "text/xml; charset=utf-8");
            headers.add("Content-Length", String.valueOf(xml.length()));
            RestTemplate rt = new RestTemplate();
            HttpEntity<String> entity = new HttpEntity<>(xml, headers);
            ResponseEntity<String> resEntity = rt.exchange(url, HttpMethod.POST, entity, String.class);
            response = resEntity.getBody();
            cmsresult = xmlToJson(response, "GetCmsContentResult");
            resp.put("success", true);
            resp.put("cms_content_result", cmsresult);
            resp.put("xml_response", response);
            resp.put("xml_request", xml);

        } catch (Exception e) {
            e.printStackTrace();
            resp.put("success", false);
            resp.put("error", e.getMessage());
        }
        return resp.toString();
    }

}


