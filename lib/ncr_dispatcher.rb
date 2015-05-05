# This is a temporary way to handle a notification preference
# that will eventually be managed at the user level
# https://www.pivotaltracker.com/story/show/87656734

class NcrDispatcher < LinearDispatcher

  def requires_approval_notice?(approval)
    final_approval(approval.proposal) == approval
  end

  def final_approval(proposal)
    proposal.approvals.last
  end

  # Notify approvers who have already approved that this proposal has been
  # modified. Also notify current approvers that the proposal has been updated
  def on_proposal_update(proposal)
    proposal.approvals.approved.each{|approval|
      CommunicartMailer.proposal_notification_email(
        approval.user_email_address, approval, false, "already_approved"
      ).deliver
    }
    proposal.currently_awaiting_approvals.each{|approval|
      if approval.api_token
        CommunicartMailer.proposal_notification_email(
          approval.user_email_address, approval, true, "updated"
        ).deliver
      else
        approval.create_api_token!
        CommunicartMailer.proposal_notification_email(
          approval.user_email_address, approval).deliver
      end
    }
  end
end
