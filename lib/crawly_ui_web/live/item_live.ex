defmodule CrawlyUIWeb.ItemLive do
  use Phoenix.LiveView

  alias CrawlyUI.Manager

  import CrawlyUIWeb.PaginationHelpers

  def render(%{template: template} = assigns) do
    CrawlyUIWeb.ItemView.render(template, assigns)
  end

  # show item view
  def mount(%{"job_id" => job_id, "id" => item_id}, _session, socket) do
    item = Manager.get_item!(item_id)
    next_item = Manager.next_item(item)

    {:ok, assign(socket, template: "show.html", item: item, next_item: next_item, job_id: job_id)}
  end

  # index view
  def mount(%{"job_id" => job_id} = params, _session, socket) do
    items = Manager.list_items(job_id, params)

    live_update(socket, :update_items, 100)

    page = Map.get(params, "page", "1") |> String.to_integer()

    rows = paginate(items, page)

    {:ok,
     assign(socket, template: "index.html", page: page, items: items, job_id: job_id, rows: rows)}
  end

  def handle_info(:update_items, socket) do
    job_id = socket.assigns.job_id
    search = socket.assigns.search
    page = socket.assigns.page

    items = Manager.list_items(job_id, %{"search" => search})
    rows = paginate(items, page)

    # If job is still running, we will update the item view
    %{state: state} = Manager.get_job!(job_id)

    if state == "running" or state == "new" do
      live_update(socket, :update_items, 1000)
    end

    {:noreply, assign(socket, items: items, rows: rows)}
  end

  def handle_params(params, _url, socket) do
    search =
      case Map.get(params, "search") do
        search when search == nil or search == "" ->
          nil

        search ->
          search
      end

    {:noreply, assign(socket, search: search)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    job_id = socket.assigns.job_id

    page = socket.assigns.page

    items = Manager.list_items(job_id, %{"search" => search})
    rows = paginate(items, page)

    {:noreply,
     assign(socket, items: items, rows: rows)
     |> push_patch(
       to: CrawlyUIWeb.Router.Helpers.item_path(socket, :index, job_id, search: search)
     )}
  end

  def handle_event("show_item", %{"job" => job_id, "item" => item_id}, socket) do
    {:noreply,
     push_redirect(socket,
       to: CrawlyUIWeb.Router.Helpers.item_path(socket, :show, job_id, item_id)
     )}
  end

  def handle_event("job_items", %{"job" => job_id}, socket) do
    {:noreply,
     push_redirect(socket, to: CrawlyUIWeb.Router.Helpers.item_path(socket, :index, job_id))}
  end

  def handle_event("goto_page", %{"page" => page}, socket) do
    job_id = socket.assigns.job_id

    {:noreply,
     push_redirect(socket,
       to: CrawlyUIWeb.Router.Helpers.item_path(socket, :index, job_id, page: page)
     )}
  end

  defp live_update(socket, state, time) do
    if connected?(socket), do: Process.send_after(self(), state, time)
  end
end