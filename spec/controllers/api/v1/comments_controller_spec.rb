require "rails_helper"

RSpec.describe Api::V1::CommentsController, type: :controller do
  describe "GET /api/v1/comments" do
    it "retrieves the ten most recent comments" do
      create_list(:comment, 10)
      comments = create_list(:comment, 10)

      get :index
      json = JSON.parse(response.body)
      ids = json.map { |c| c["id"] }

      expect(response.content_type).to eq("application/json")
      expect(response).to have_http_status(:ok)
      expect(ids).to match_array(comments.map(&:id))
    end

    it "retrieves comments associated with a video" do
      video = create(:video)
      comments = create_list(:comment, 5, video: video)
      create_list(:comment, 5)

      get :index, params: { video_id: video.id }
      json = JSON.parse(response.body)
      ids = json.map { |c| c["id"] }

      expect(response.content_type).to eq("application/json")
      expect(response).to have_http_status(:ok)
      expect(ids).to match_array(comments.map(&:id))
    end
  end

  describe "GET /api/v1/comments/:id" do
    it "retrieves a single comment" do
      comment = create(:comment)

      get :show, params: { id: comment.id }
      json = JSON.parse(response.body)

      expect(response.content_type).to eq("application/json")
      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(comment.id)
      expect(json["title"]).to eq(comment.title)
      expect(json["content"]).to eq(comment.content)
    end
  end

  # Add the comment creation test here
  describe "POST /api/v1/comments" do
  # this test tests the controllers response to the request to create a comment
    it "creates a new comment" do
    # a Comment object is built but not persisted to the database
      comment = build(:comment)

    # Rspec allows us to make a request with HTTP verbs (post),
    # specify a method in the controller to call (:create)
    # as well as specify params to be made available in the method
      post :create, params: { comment: comment.attributes }

    # a response object is created when the test receives a response
    # assert that the response has a specific HTTP status
      expect(response).to have_http_status(:created)
    # assert that the response has a header with a specific value
      expect(response.header["Location"]).to match /\/api\/v1\/comments/
    end

    it "returns 'not_found' if validations fail" do
      post :create, params: { comment: { title: "", content: "", video_id: 0 } }
      expect(response).to have_http_status(:not_found)
    end
  end

end
