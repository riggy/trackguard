require "rails_helper"

RSpec.describe Trackguard::PageTracker, type: :controller do
  context "with track_page_views on all actions" do
    controller(ApplicationController) do
      include Trackguard::PageTracker
      track_page_views

      def index
        head :ok
      end
    end

    it "enqueues TrackPageViewJob after a GET HTML request" do
      expect { get :index }.to have_enqueued_job(Trackguard::TrackPageViewJob)
    end

    it "does not enqueue for a POST request" do
      expect { post :index }.not_to have_enqueued_job
    end

    it "does not enqueue for a non-HTML GET (JSON)" do
      expect { get :index, format: :json }.not_to have_enqueued_job
    end
  end

  context "with track_page_views only: :show" do
    controller(ApplicationController) do
      include Trackguard::PageTracker
      track_page_views only: :show

      def index; head :ok; end
      def show;  head :ok; end
    end

    before { routes.draw { get "show" => "anonymous#show"; get "index" => "anonymous#index" } }

    it "tracks the specified action" do
      expect { get :show }.to have_enqueued_job(Trackguard::TrackPageViewJob)
    end

    it "does not track excluded actions" do
      expect { get :index }.not_to have_enqueued_job
    end
  end

  context "with track_page_views except: :index" do
    controller(ApplicationController) do
      include Trackguard::PageTracker
      track_page_views except: :index

      def index; head :ok; end
      def show;  head :ok; end
    end

    before { routes.draw { get "show" => "anonymous#show"; get "index" => "anonymous#index" } }

    it "tracks actions not in the except list" do
      expect { get :show }.to have_enqueued_job(Trackguard::TrackPageViewJob)
    end

    it "does not track excepted actions" do
      expect { get :index }.not_to have_enqueued_job
    end
  end
end
