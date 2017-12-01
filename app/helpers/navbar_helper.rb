module NavbarHelper
  def nav_link(link_text, controller, link_path)
    class_name = controller_name == controller ? 'active nav-link' : 'nav-link'

    content_tag(:li, :class => class_name ) do
      link_to link_text, link_path
    end
  end

  def nav_dropdown_link(link_text, controller, action, link_path)
    class_name = controller_name == controller && action_name == action ? 'active nav-link' : 'nav-link'

    content_tag(:li, :class => class_name ) do
      link_to link_text, link_path
    end
  end
end
