require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    query_params = Kemal::ParamParser.new(request).query
    query_params["hasan"].should eq "cemal"
  end

  context "#query" do
    it "parses multiple values for query params" do
      request = HTTP::Request.new("POST", "/?hasan=cemal&hasan=lamec")
      query_params = Kemal::ParamParser.new(request).query
      query_params["hasan"].should eq ["cemal", "lamec"]
    end
  end

  context "#url" do
    it "parses url params" do
      kemal = Kemal::RouteHandler::INSTANCE
      kemal.add_route "POST", "/hello/:hasan" do |env|
        "hello #{env.params.url["hasan"]}"
      end
      request = HTTP::Request.new("POST", "/hello/cemal")
      # Radix tree MUST be run to parse url params.
      io_with_context = create_request_and_return_io(kemal, request)
      url_params = Kemal::ParamParser.new(request).url
      url_params["hasan"].should eq "cemal"
    end

    it "decodes url params" do
      kemal = Kemal::RouteHandler::INSTANCE
      kemal.add_route "POST", "/hello/:email/:money/:spanish" do |env|
        email = env.params.url["email"]
        money = env.params.url["money"]
        spanish = env.params.url["spanish"]
        "Hello, #{email}. You have #{money}. The spanish word of the day is #{spanish}."
      end
      request = HTTP::Request.new("POST", "/hello/sam%2Bspec%40gmail.com/%2419.99/a%C3%B1o")
      # Radix tree MUST be run to parse url params.
      io_with_context = create_request_and_return_io(kemal, request)
      url_params = Kemal::ParamParser.new(request).url
      url_params["email"].should eq "sam+spec@gmail.com"
      url_params["money"].should eq "$19.99"
      url_params["spanish"].should eq "año"
    end
  end

  context "#body" do
    it "parses request body" do
      request = HTTP::Request.new(
        "POST",
        "/?hasan=cemal",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      query_params = Kemal::ParamParser.new(request).query
      {"hasan" => "cemal"}.each do |k, v|
        query_params[k].should eq(v)
      end

      body_params = Kemal::ParamParser.new(request).body
      {"name" => "serdar", "age" => "99"}.each do |k, v|
        body_params[k].should eq(v)
      end
    end

    it "parses multiple values in request body" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "hasan=cemal&hasan=lamec",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      body_params = Kemal::ParamParser.new(request).body
      body_params["hasan"].should eq(["cemal", "lamec"])
    end

    it "parses array values in request body" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "framework=kemal&feats[]=fast&feats[]=effective&feats[]=simple",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      body_params = Kemal::ParamParser.new(request).body
      body_params["framework"].should eq("kemal")
      body_params["feats[]"].should eq(["fast", "effective", "simple"])
    end
  end

  context "#json" do
    it "parses request body" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body when passed charset" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json; charset=utf-8"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body for array" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"_json" => [1]})
    end

    it "parses request body and query params" do
      request = HTTP::Request.new(
        "POST",
        "/?foo=bar",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      query_params = Kemal::ParamParser.new(request).query
      {"foo" => "bar"}.each do |k, v|
        query_params[k].should eq(v)
      end

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"_json" => [1]})
    end

    it "handles no request body" do
      request = HTTP::Request.new(
        "GET",
        "/",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      url_params = Kemal::ParamParser.new(request).url
      url_params.should eq({} of String => String)

      query_params = Kemal::ParamParser.new(request).query
      query_params.to_s.should eq("")

      body_params = Kemal::ParamParser.new(request).body
      body_params.to_s.should eq("")

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({} of String => Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type))
    end
  end

  context "when content type is incorrect" do
    it "does not parse request body" do
      request = HTTP::Request.new(
        "POST",
        "/?hasan=cemal",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type" => "text/plain"},
      )

      query_params = Kemal::ParamParser.new(request).query
      query_params["hasan"].should eq("cemal")

      body_params = Kemal::ParamParser.new(request).body
      body_params.to_s.should eq("")
    end
  end
end
