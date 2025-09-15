class GoogleVideoAnalyzer
  BASE_URL = "https://generativelanguage.googleapis.com"
  FILES_UPLOAD_PATH = "/upload/v1beta/files"
  DEFAULT_MODEL = ENV.fetch("GEMINI_MODEL", "gemini-2.0-flash")

  def initialize(api_key: ENV["GEMINI_API_KEY"], model: DEFAULT_MODEL)
    @api_key = api_key or raise "Missing GEMINI_API_KEY"
    @model   = model
  end

  def call(video:, prompts:)
    bytes, mime, name = coerce_video(video)
    upload_url = start_resumable_upload(content_length: bytes.bytesize, content_type: mime, display_name: name)
    file_uri   = upload_and_finalize(upload_url, bytes)
    sleep 5 # wait for processing make this better in prod
    analyze_video(file_uri: file_uri, mime: mime, prompts: prompts)
  end

  private

  def coerce_video(video)
    if video.respond_to?(:tempfile)
      bytes = File.binread(video.tempfile.path)
      mime  = video.content_type.presence || "video/mp4"
      name  = video.original_filename.presence || "video.mp4"
    elsif video.is_a?(File)
      bytes = video.binmode.read
      mime  = "video/mp4"
      name  = File.basename(video.path)
    elsif video.is_a?(String) && File.exist?(video)
      bytes = File.binread(video)
      mime  = "video/mp4"
      name  = File.basename(video)
    else
      raise ArgumentError, "Unsupported video input"
    end
    [bytes, mime, name]
  end

  def start_resumable_upload(content_length:, content_type:, display_name:)
    res = HTTParty.post(
      "#{BASE_URL}#{FILES_UPLOAD_PATH}",
      query:  { key: @api_key },
      headers: {
        "X-Goog-Upload-Protocol" => "resumable",
        "X-Goog-Upload-Command"  => "start",
        "X-Goog-Upload-Header-Content-Length" => content_length.to_s,
        "X-Goog-Upload-Header-Content-Type"   => content_type,
        "Content-Type" => "application/json"
      },
      body: { file: { display_name: display_name } }.to_json
    )
    
    url = res.headers["x-goog-upload-url"]
    raise "Failed to start upload: #{res.code}" if url.nil?
    url
  end

  def upload_and_finalize(upload_url, bytes)
    res = HTTParty.post(
      upload_url,
      headers: {
        "Content-Length" => bytes.bytesize.to_s,
        "X-Goog-Upload-Offset"  => "0",
        "X-Goog-Upload-Command" => "upload, finalize"
      },
      body: bytes
    )
    uri = res.parsed_response.dig("file", "uri")
    raise "Upload finalize failed: #{res.code} #{res.body}" if uri.nil?
    uri
  end

  def analyze_video(file_uri:, mime:, prompts:)
    parts = prompts.map { |p| { text: p.to_s } }
    parts << { file_data: { mime_type: mime, file_uri: file_uri } }

    res = HTTParty.post(
      "#{BASE_URL}/v1beta/models/#{@model}:generateContent",
      query:   { key: @api_key },
      headers: { "Content-Type" => "application/json" },
      body:    { contents: [{ parts: parts }] }.to_json
    )

    unless res.success?
      raise "Gemini error #{res.code}: #{res.body}"
    end

    text = Array(res.parsed_response.dig("candidates", 0, "content", "parts"))
             .map { |p| p["text"] }
             .compact
             .join("\n")
    { text: text, file_uri: file_uri }
  end
end