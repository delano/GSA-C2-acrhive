class CommunicartMailer < ApplicationMailer
  layout 'communicart_mailer'
  add_template_helper CommunicartMailerHelper
  add_template_helper ValueHelper
  add_template_helper ClientHelper
  add_template_helper MarkdownHelper

  # Approver can approve/take other action
  def actions_for_approver(to_email, approval, alert_partial = nil)
    @show_approval_actions = true
    proposal = approval.proposal

    self.notification_for_subscriber(to_email, proposal, alert_partial, approval)
  end

  def notification_for_subscriber(to_email, proposal, alert_partial = nil, approval = nil)
    @approval = approval
    @alert_partial = alert_partial

    send_proposal_email(
      from_email: user_email_with_name(proposal.requester),
      to_email: to_email,
      proposal: proposal,
      template_name: 'proposal_notification_email'
    )
  end

  def on_observer_added(observation)
    @observation = observation
    observer = observation.user

    send_proposal_email(
      from_email: observation_added_from(observation),
      to_email: observer.email_address,
      proposal: observation.proposal
    )
  end

  def proposal_observer_email(to_email, proposal)
    # TODO have the from_email be whomever triggered this notification
    send_proposal_email(
      to_email: to_email,
      proposal: proposal
    )
  end
  alias_method :cancellation_email, :proposal_observer_email

  def proposal_created_confirmation(proposal)
    send_proposal_email(
      to_email: proposal.requester.email_address,
      proposal: proposal
    )
  end
  alias_method :cancellation_confirmation, :proposal_created_confirmation

  def approval_reply_received_email(approval)
    proposal = approval.proposal
    @approval = approval
    @alert_partial = 'approvals_complete' if proposal.approved?

    send_proposal_email(
      from_email: user_email_with_name(approval.user),
      to_email: proposal.requester.email_address,
      proposal: proposal
    )
  end

  def comment_added_email(comment, to_email)
    @comment = comment
    # Don't send if special comment
    unless @comment.update_comment
      send_proposal_email(
        from_email: user_email_with_name(comment.user),
        to_email: to_email,
        proposal: comment.proposal
      )
    end
  end

  private

  def send_proposal_email(proposal:, to_email:, from_email: nil, template_name: nil)
    @proposal = proposal.decorate

    # http://www.jwz.org/doc/threading.html
    headers['In-Reply-To'] = @proposal.email_msg_id
    headers['References'] = @proposal.email_msg_id

    mail(
      to: to_email,
      subject: proposal_subject(@proposal),
      from: from_email || default_sender_email,
      template_name: template_name
    )
  end

  def proposal_subject_i18n_key(proposal)
    if proposal.client_data
      # We'll look up by the client_data's class name
      proposal.client_data.class.name.underscore
    else
      # Default (no client_data): look up by "proposal"
      :proposal
    end
  end

  def proposal_subject_params(proposal)
    params = proposal.as_json
    # todo: replace with public_id once #98376564 is fixed
    params[:public_identifier] = proposal.public_identifier
    # Add in requester params
    proposal.requester.as_json.each { |k, v| params["requester_" + k] = v }
    if proposal.client_data
      # Add in client_data params
      params.merge!(proposal.client_data.as_json)
    end
    # Add search path, and default lookup key for I18n
    params.merge!(scope: [:mail, :subject], default: :proposal)

    params
  end

  def proposal_subject(proposal)
    i18n_key = proposal_subject_i18n_key(proposal)
    params = proposal_subject_params(proposal)
    I18n.t(i18n_key, params.symbolize_keys)
  end

  def observation_added_from(observation)
    adder = observation.created_by
    if adder
      user_email_with_name(adder)
    else
      nil
    end
  end
end
