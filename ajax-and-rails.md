### Introduction

Up to this point, we have been utilizing Rails controllers to accept HTTP requests for a resource, and having them respond with an HTML representation of that resource. Now, we will explore an alternative way for Rails controllers to present resources to the client. To get started:
  1. et get ajax-and-rails
  2. cd ajax-and-rails
  3. rake db:create
  4. rake db:migrate
  5. rake db:seed
  6. rake db:test:prepare

### Building a Video Review App

In the application provided, we have CRUD functionality for the Video model. We would like to add the ability for users to create comments on movies, asynchronously. As always, let's start with a feature spec. Add the following code to spec/features/comment_spec.rb to test comment creation.

```ruby
feature "comment spec" do
  let(:video) { create(:video) }

  scenario "create comment on video" do
    visit video_path(video)
    within "div.new-comment" do
      fill_in "Title", with: "Eh, it was alright."
      fill_in "Content", with: "You can probably skip this one."
      click_button "Create Comment"
    end
    expect(page).to have_content("Thank you for your input!")
  end

  scenario "video comment fields not filled out" do
    visit video_path(video)
    within "div.new-comment" do
      click_button "Create Comment"
    end
    expect(page).to have_content("There was an issue with your comment.")
    expect(page).to have_content("can't be blank")
  end
end
```

We have provided this basic functionality. Run the test suite to ensure this test is passing. Later on, we will want to prevent the form submission, and submit the data to a new API endpoint on our Video Store application using AJAX.

#### API Endpoint

In order for AJAX to work, we need a place in our application to POST the JSON representation of a comment. We will create a separate API Comments Controller to handle this. The first step, as always, is a test. Review this test and the detailed comments included. Then put this code in spec/controllers/api/v1/comments_controller_spec.rb as noted.

```ruby
RSpec.describe Api::V1::CommentsController, type: :controller do

  # other tests ...

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
```

When writing controller tests for a JSON endpoint, the important things to test are 1) the HTTP response code and 2) the body of the response. When posting data, we don't expect anything to be returned in the body of the response. So, testing the body of the response here isn't necessary.

#### Building Server-Side Functionality

Running the tests and reading the errors will guide us to building the feature. First, we need a route to the API controller. To establish this route, add the following code to config/routes.rb.

```ruby
  namespace :api do
    namespace :v1 do
      resources :comments, only: [:index, :show, :create]
    end
  end
```

The next step is to build the Comments controller for our API. This is just like any other Rails controller, except it will only ever accept JSON and render JSON. To implement this controller, add the following code to app/controllers/api/v1/comments_controller.rb.

```ruby
  def index
    if params[:video_id]
      video = Video.find(params[:video_id])
      comments = Comment.where(video: video)
    else
      comments = Comment.order(created_at: :desc).limit(10)
    end

    render json: comments
  end

  def show
    comment = Comment.find(params[:id])
    render json: comment
  end

  def create
    comment = Comment.new(comment_params)
    if comment.save
      render json: :nothing, status: :created, location: api_v1_comments_path(comment)
    else
      render json: :nothing, status: :not_found
    end
  end

  private
  def comment_params
    params.require(:comment).permit(:title, :content, :video_id)
  end
```

There are currently several tests in the spec/controllers/api/v1/comments_controller_spec.rb file that are marked pending (with an "xdescribe"). Remove the "x" and run the test suite. This gives us the feedback that the server-side functionality of posting a comment is working. We can also test this manually. Start the `rails server` and try out the following code in the Chrome Developer Console.

```js
var response = $.ajax({
  method: "POST",
  url: "/api/v1/comments",
  data: {
    comment: {
      title: "Yeah, it was ok.",
      content: "Test comment content",
      video_id: 1
    }
  }
});
```

![request](http://i.imgur.com/iDDP3fs.png)

Check that the response was successful.

![response](http://i.imgur.com/0FI4PQ6.png)

We can also verify that the comment was saved by refreshing the video show page.

### Building the Client-Side Functionality

When the client interacts with the comment form, we want perform the following actions on the client-side:

1. Prevent the default action of the browser submitting the form.
2. Pull the data from the form (Using JS or jQuery).
3. Perform an AJAX POST request with the form data.
4. Update the page once we receive a response.


As always, we should write tests for this functionality, first.

#### Jasmine + Rails

We covered testing JavaScript with Jasmine in an earlier assignment. The [teaspoon gem](https://github.com/modeset/teaspoon) makes adding Jasmine tests to our Rails apps dead simple.

1. Add `gem 'teaspoon'` and `gem 'teaspoon-jasmine'` to the test and development groups in the `Gemfile`.
2. Then, `bundle`.
3. Run the `rails generate teaspoon:install` command to create a `spec/javascripts` folder. This is where your JS tests will live

#### Testing JavaScript Functionality with Jasmine

The first task is to extract data from the form.

1. Create a file in `spec/javascripts` and name it `comment_form_spec.js`.
2. Add these tests to the newly created file:

```js
describe("CommentForm", function() {
  var form, commentForm;

  beforeEach(function() {
    form = $([
      '<form id="new_comment" action="/videos/42/comments" method="post">',
      '<input type="text" name="comment[title]" id="comment_title" />',
      '<textarea name="comment[content]" id="comment_content"></textarea>'
    ].join('\n'));

    commentForm = newCommentForm(form);

    form.find("#comment_title").val("Cinematic Gold!");
    form.find("#comment_content").val("You have to see this.");
  });

  describe("new", function() {
    it("creates a new CommentForm object", function() {
      expect(commentForm).toBeDefined();
    });

    it("sets the element property", function() {
      expect(commentForm.element).toBeDefined();
    });
  });

  describe("title", function() {
    it("retrieves the title from the form", function() {
      expect(commentForm.title()).toBe("Cinematic Gold!");
    });
  });

  describe("content", function() {
    it("retrieves the title from the form", function() {
      expect(commentForm.content()).toBe("You have to see this.");
    });
  });

  describe("videoId", function() {
    it("retrieves the video id from the form", function() {
      expect(commentForm.videoId()).toBe("42");
    });
  });

  describe("attributes", function() {
    it("returns an object of comment attributes", function() {
      result = {
        title: "Cinematic Gold!",
        content: "You have to see this.",
        video_id: "42"
      }
      expect(commentForm.attributes()).toEqual(result);
    });
  });
});
```

We can run our JavaScript tests with the `rake teaspoon` command. Or, we can execute our tests in the browser by firing up a `rails server` and visiting [localhost:3000/teaspoon](http://localhost:3000/teaspoon). The latter might be preferred when developing, since you can insert `debugger;` statements and interact with your code in the Developer Console. Run your tests and observe the failures now.

In order to test our JavaScript object, we need a **fixture**, a chunk of HTML for our JavaScript to interact with. In this case, we have used an array of strings and jQuery to help us to create the `form` variable which contains some input fields.

The `attributes` function of the CommentForm object returns an object of comment attributes. This will come in handy when we need to POST this data to the server using AJAX.

Add this code to: `app/assets/javascripts/comment_form.js`

```js
var newCommentForm = function(formId) {
  return {
    element: $(formId),
    title: function() {
      return this.element.find("#comment_title").val();
    },
    content: function() {
      return this.element.find("#comment_content").val();
    },
    videoId: function() {
      var postPath = this.element.attr("action");
      var regex = /\/videos\/(\d+)\/comments/;
      var matches = postPath.match(regex);
      var result;
      if(matches.length === 2) {
        result = matches[1];
      }
      return result
    },
    attributes: function() {
      var result = {
        title: this.title(),
        content: this.content(),
        video_id: this.videoId()
      }
      return result;
    }
  }
}
```

This code allows us to extract the relevant information from the form in an object-oriented way. Run your tests again to make sure they pass.

#### AJAX to the Rescue

Now that we have extracted the relevant information from the comment form, our next task is to submit this information to the API endpoint. Let's build a `CommentCreator` class to assist us in this endeavor.

1. Create a new file in `spec/javascripts` named `comment_creator_spec.js`
2. Add the following code to the newly created file:

```js
describe("CommentCreator", function() {
  beforeEach(function() {
    jasmine.Ajax.install();
  });

  afterEach(function() {
    jasmine.Ajax.uninstall();
  });

  var attributes = {
    title: "Cinematic Gold!",
    content: "You have to see this.",
    video_id: "42"
  }

  var commentsSection = $("<div>", { "id": "comments" });

  var commentCreator = newCommentCreator(attributes, commentsSection);

  describe("new", function() {
    it("creates a new CommentCreator object", function() {
      expect(commentCreator).toBeDefined();
    });
  });

  describe("create", function() {
    it("issues a POST request to /api/v1/comments", function() {
      commentCreator.create();
      var request = jasmine.Ajax.requests.mostRecent();
      expect(request.method).toBe("POST");
      expect(request.url).toBe("/api/v1/comments");
    });
  });

  describe("setFlash", function() {
    it("adds a new div to the body of the DOM", function() {
      commentCreator.setFlash("notice", "Hey there!");
      var flash = $("div.flash-notice")
      expect(flash.text()).toBe("Hey there!");
    });
  });

  describe("append", function() {
    it("adds the comment to the comment section", function() {
      commentCreator.append();
      expect(commentsSection.find("h3").text()).toBe("Cinematic Gold!");
      expect(commentsSection.find("p").text()).toBe("You have to see this.");
    });
  });
});
```

We will utilize the `mock-ajax.js` library provided by Jasmine framework to test AJAX functionality.

1. Download the [`mock-ajax.js`](https://jasmine.github.io/2.3/ajax.html) file
2. Place it in the `spec/javascripts/support` folder.
3. We also need to add the following line to the `spec/javascripts/spec_helper.js` file:

```js
//= require support/mock-ajax
```

Notice above our call to the `commentCreator`'s `create()` method.
When we get around to writing this method, it will fire off an AJAX request, and thanks to Jasmine we can halt and capture that request behavior.
In order to capture our AJAX request, the call to `jasmine.Ajax.requests.mostRecent();` gives us the most recent request made. We can then test that we are making the proper type of request to the correct path.

**Optional Challenge:** Add more "expect"s in the `create()` test example to validate the data sent in the request.

#### Notifying the User

After the POST request has been made, and the client has received a HTTP response, we should alert the user that something happened. We can test for this with by adding the following code to the `describe("create")` block in the comment_creator_spec.js file.

```js
it("notifies the user after posting the data", function() {
  spyOn(commentCreator, "setFlash");
  commentCreator.create();
  var request = jasmine.Ajax.requests.mostRecent();
  request.respondWith({ status: 201 });
  expect(commentCreator.setFlash).toHaveBeenCalled();
});
```

In order to test that a function is called, we need to **spy** on it. [Spies](https://jasmine.github.io/2.3/introduction.html#section-Spies) are special test functions provided by Jasmine that allow us to determine if a function has been called. Here, we are watching the `setFlash` function on the `CommentCreator` object, and verifying it is called after we receive a response from our AJAX request.

Now that we have tests, we need to implement the functionality. To do this, place the following code in the app/javascripts/comment_creator.js file. This code will make the AJAX request to the server to add the new item to the list. It will also notify the user whether the operation was successful or not.

```js
var newCommentCreator = function(commentAttributes, divId) {
  return {
    comment: commentAttributes,
    div: $(divId),
    create: function() {
      var commentCreatorObject = this;
      var request = $.ajax({
        method: "POST",
        url: "/api/v1/comments",
        data: { comment: commentCreatorObject.comment }
      });

      request.done(function() {
        commentCreatorObject.setFlash("notice", "Thank you for your input!");
        commentCreatorObject.append();
      });

      request.error(function() {
        commentCreatorObject.setFlash("error", "There was a problem with your comment.");
      });
    },
    setFlash: function(type, message) {
      $("div.flash").remove();
      var flash = $("<div>", { "class": "flash flash-" + type }).text(message);
      $("body").prepend(flash);
    },
    append: function() {
      // add the comment to the DOM
    }
  }
};
```

Note that when dealing with the AJAX callback, we lose the context of `this`. In order to maintain that context, we create a variable `commentCreatorObject`, so that we can successfully call the `setFlash` method. Read more about `this`, [here](http://javascriptissexy.com/understand-javascripts-this-with-clarity-and-master-it/).

#### Wiring it all Up

We have done a good job of unit testing our JavaScript. Now, we should wire it to the form and test it out manually. Add the following code to the app/javascripts/application.js file.

```js
// app/javascripts/application.js

$(function() {
  $("form#new_comment").submit(function(event) {
    event.preventDefault();
    var commentForm = newCommentForm("form#new_comment");
    var commentCreator = newCommentCreator(commentForm.attributes(), "div#comments");
    commentCreator.create();
  });
});
```

#### Optional Challenges:

There is functionality to be added! Wouldn't it be nice if the form was cleared when a comment was submitted successfully? Also, we have neglected to add the new comment to the page when it is successfully created. Write tests and corresponding code for these features!


### Wrap Up

We have covered...

* How to write controller tests for a Rails application
* How to implement an API endpoint that accepts AJAX POST requests
* How to unit test JavaScript objects with the Jasmine framework

Testing our client-side code is just as important as testing our server-side code. We should always strive for near 100% test coverage. We can now add Jasmine to our toolbox to help us with this goal.
