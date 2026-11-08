module AdminHelper
  EYE_ICONS = '<svg class="eye-open" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>' \
              '<svg class="eye-shut" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 3l18 18"/><path d="M10.6 5.1A10.8 10.8 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4.1M6.6 6.6A17 17 0 0 0 2 12s3.5 7 10 7a10 10 0 0 0 5.4-1.6"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg>'.html_safe

  # Masks a sensitive value, keeping only `keep` characters at the start or end ("••••5678").
  # The full value is only sent to the page for administrators who may reveal it (super admins).
  def admin_masked(value, keep: 4, from: :end)
    return tag.span("—", class: "muted") if value.blank?
    text = value.to_s
    keep = [ keep, text.length / 2 ].min
    dots = "•" * [ text.length - keep, 4 ].max.clamp(4, 8)
    masked = from == :end ? "#{dots}#{text.last(keep)}" : "#{text.first(keep)}#{dots}"
    return tag.span(masked, class: "mono masked-dots", title: "Hidden. Only super admins can reveal it.") unless can?(:reveal)

    tag.span(class: "masked", data: { reveal_target: "item" }) do
      tag.span(text, class: "masked-value mono") + tag.span(masked, class: "masked-dots mono", aria: { hidden: true }) +
        tag.button(EYE_ICONS, type: "button", class: "reveal-btn", data: { action: "reveal#toggle" }, aria: { pressed: false, label: "Show value" })
    end
  end

  def access_badge(admin)
    tone = { "all" => "badge-god", "view" => "badge-muted" }.fetch(admin.access_level, "badge-info")
    tag.span(admin.super_admin? ? "⚡ #{admin.access_label}" : admin.access_label, class: "badge #{tone}")
  end

  def user_status_badge(user)
    if user.onboarded? then tag.span("Active", class: "badge badge-good")
    elsif !user.invoice_details_complete? then tag.span("Needs invoice details", class: "badge badge-warn")
    else tag.span("Needs lock code", class: "badge badge-warn")
    end
  end

  def avatar(name, size: nil)
    tag.span(name.to_s.split.map(&:first).first(2).join.upcase, class: [ "avatar", ("avatar-#{size}" if size) ])
  end

  # Nav link in the admin sidebar, active for its controller.
  def admin_nav_link(label, path, icon, controllers)
    active = controllers.include?(controller_name)
    link_to path, class: ("active" if active), aria: { current: ("page" if active) } do
      tag.span(icon, class: "nav-icon", aria: { hidden: true }) + tag.span(label)
    end
  end
end
