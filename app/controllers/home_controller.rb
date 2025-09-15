class HomeController < ApplicationController
  def index; end

  def analyze
    prompts = [
      "Suggest Create Academy courses that match this video and explain why.",
      "If no courses match pick some other relevant courses from the Create Academy catalog.",
      "List 3 actionable beginner tips.",
      "Create Academy is an online learning platform that offers visual learning and a desire to uncover how exceptional creatives work.",
      "The course catalog is available at https://www.createacademy.com/online-courses",
      "This response is customer facing so keep it concise and avoid jargon and tailor wordings positivly.",
    ]
    @result = GoogleVideoAnalyzer.new.call(video: params.require(:video), prompts: prompts)


    respond_to do |format|
      format.turbo_stream  # will render analyze.turbo_stream.erb
      format.html { redirect_to root_path, notice: "Analyzed" }
      format.json { render json: @result }
    end
  rescue => e
    @error = e.message
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "response",
          partial: "home/error",
          locals: { message: @error }
        )
      end
      format.html { redirect_to root_path, alert: @error }
      format.json { render json: { error: @error }, status: :unprocessable_entity }
    end
  end
end
