JsOsaDAS1.001.00bplist00?Vscript_?var app	= Application('Mail');

DeleteDuplicateEmails();

function DeleteDuplicateEmails()
{
	var msgs 		= GetSelectedMessages();
	let numMessages = msgs.length;
	console.log("Reviewing " + numMessages + " messages for deletion!");
	for (let x = 0, status = 0; x < numMessages; x++, status++)
	{
		if(status > 48)
		{
			console.log(x+1 + " messages reviewed so far");
			status = -1;
		}
		if(msgs[x].toDelete) 										// skip if we're already deleting msgs[x]
			continue;

		for(let y = x + 1; y < numMessages; y++)
		{
			if(msgs[y].toDelete) 									// skip if we're already deleting msgs[y]
				continue;

			if (msgs[x].cleanSubject() === msgs[y].cleanSubject())	// Compare subjects. We're not bothering with recipients
			{ 														//		or senders. We only care about the content
				if (msgs[x].dateSent() > msgs[y].dateSent())
				{
					MessageMatchOldestSecond(msgs[x], msgs[y]);
				}
				else
				{
					MessageMatchOldestSecond(msgs[y], msgs[x]);
					if(msgs[x].toDelete)
						break;										// x will be deleted. Cycle to the next x
				}
			}
			else
				break;												// The list is sorted. There are no more to look for
		}
		msgs[x].ReleaseMemory();									// Large list can consume a lot of memory 
	}																//			- free what we don't need anymore
	console.log("Completed review");
	let deletedcount = DeleteMarkedMessages(msgs);
	return "Completed. Deleted " + deletedcount + " messages";
}

function GetTrashMailbox(accountName)
{
	let numTrashMailboxes 	= app.trashMailbox.mailboxes.length;	// All .length references are spiked out 
	let numAccounts 		= app.accounts.length;					//			from loops for performance reasons

	for(let x =0; x< numTrashMailboxes; x++)
	{
		let mbox = app.trashMailbox.mailboxes[x];
		
		if(accountName != null)
		{
			let mboxName = mbox.name();
			for(let y=0; y < numAccounts; y++)
			{
				let foundacct = app.accounts[y];
				if(foundacct.name() === accountName)
				{
					let foundTrash = foundacct.mailboxes.byName(mboxName);
					if(foundTrash() == null)
						return app.trashMailbox.mailboxes.byName("Trash");
					return foundTrash;
				}
			}
		}
		else if(mbox.account() == null)
			return mbox;
	}
	return app.trashMailbox.mailboxes.byName("Trash");
}

function GetSelectedMessages()
{
	class MailWrapper 
	{
		#mailbox;
		#id;
		#subject;
		#dateSent;
		#bodyArray;
		#trashMailbox;
		#cleanSubject;
		#numAttachments;
		#message;
		#attachments;

		toDelete;
		
		constructor(mail, mailbox, trashMailbox) 
		{
			this.#mailbox			= mailbox;
			this.#trashMailbox 		= trashMailbox;
			this.#id 				= mail.id();
			this.toDelete			= false;
		}
		numAttachments()
		{
			if(this.#numAttachments == null)
				this.#numAttachments = this.mailref().mailAttachments.length;
			return this.#numAttachments;
		}
		attachments()
		{
			if(this.#attachments == null)
				this.#attachments = this.mailref().mailAttachments;
			return this.#attachments;
		}
		cleanSubject()
		{
			if(this.#cleanSubject == null)
				this.#cleanSubject 	= StripReplys(this.subject());
			return this.#cleanSubject;
		}
		id()
		{
			return this.#id;
		}
		subject()
		{
			if(this.#subject == null)
				this.#subject = this.mailref().subject();
			return this.#subject;
		}
		dateSent()
		{
			if(this.#dateSent == null)
				this.#dateSent = this.mailref().dateSent();
			return this.#dateSent;
		}
		bodyArray()
		{
			if(this.#bodyArray == null)
				this.#bodyArray = this.mailref().content().split(/\r?\n/);
			return this.#bodyArray;
		}
		mailref()
		{
			if(this.#message == null)
				this.#message = this.#mailbox.messages.byId(this.#id);
			return this.#message;
		}
		MoveToTrash()
		{
			console.log("Deleting message (" + (this.#id) + "): " + (this.subject()));
			if(this.#trashMailbox == null)
			{
				if(this.#mailbox.account() != null)
					this.#trashMailbox = GetTrashMailbox(this.#mailbox.account.name());
				else
					this.#trashMailbox = GetTrashMailbox(null);
			}
			this.mailref().mailbox = this.#trashMailbox;
		}
		ReleaseMemory()
		{
			this.#dateSent 			= null;
			this.#cleanSubject 		= null;
			this.#bodyArray 		= null;
			this.#numAttachments 	= null;
			this.#attachments		= null;
			
			if(!this.toDelete)
			{
				this.#subject 		= null;
				this.#trashMailbox 	= null;
//				this.#message		= null;
			}
		}
	}

	let mail 				= [];
	let displaystatus 		= true;
	let numAppViewers 		= app.messageViewers.length;

	for(let x = 0; x < numAppViewers; x++)
	{
		let mv 				= app.messageViewers[x];
		let mbs 			= mv.selectedMailboxes();
		let nummbs 			= mbs.length;
		if(displaystatus)
		{
			console.log("Gathering mail from " + nummbs + " mailboxes");
			displaystatus = false;
		}
		for(let y = 0; y < nummbs; y++)
		{
			let acctName 	= null;
			let mb 			= mbs[y];
			let numMsgs		= mb.messages.length;
			let start 		= mail.length;
			mail.length 	= start + numMsgs;

			if(mb.account() != null)
				acctName = mb.account.name();
			let trash = GetTrashMailbox(acctName);

			for(let l = 0; l < numMsgs; l++)
			{
				mail[start+l] = new MailWrapper(mb.messages[l], mb, trash);
			}
		}
	}
	return mail.sort(function(a,b){return a.cleanSubject().localeCompare(b.cleanSubject());});
}

// Strips off 'Re: ' or other text that is generated by mail programs
function StripReplys(s)
{
	if(s.length > 3)
	{
		if(s[2] === ':' && ((s[0] === 'R' || s[0] === 'r') && (s[1] === 'E' || s[1] === 'e') || 
			 (s[0] === 'F' || s[0] === 'f') && (s[1] === 'W' || s[1] === 'w')) && 
			  s[3] === ' ')
		{
			var str = s.substring(4);
			return StripReplys(str);
		}
		if(s.length > 4 && s[3] === ':' && (s[0] === 'F' || s[0] === 'f') && 
			(s[1] === 'W' || s[1] === 'w') && 
			(s[2] === 'D' || s[2] === 'd') && s[4] === ' ')
		{
			var str = s.substring(5);
			return StripReplys(str);
		}
	}
	return s;
}

// Deletes the messages that match the gathered IDs
//		This is done seperately from the search to keep from having indexing issues
function DeleteMarkedMessages(msgs)
{
	var tobeDeleted = 0;
	for(let i = 0; i < msgs.length; i++)
	{
		if(msgs[i].toDelete)
			tobeDeleted++;
	}
	console.log("Deleting " + tobeDeleted + " messages");
	for (let x = msgs.length -1; x > -1; x--)
	{
		if(msgs[x].toDelete)
			msgs[x].MoveToTrash();
	}
	return tobeDeleted;
}

// Decide if the older message can be deleted
//		It's possible the newer one should be deleted, but it would be rare.
function MessageMatchOldestSecond(newmsg, oldmsg)
{
	if(oldmsg.numAttachments() > 0)
	{
		if(!CompareAttachments(newmsg.attachments(), oldmsg.attachments()))
			return;
	}
	
	var newbody = newmsg.bodyArray();
	var oldbody = oldmsg.bodyArray();

	for(let x = 0, nextpos = 0; x < oldbody.length && nextpos < newbody.length; x++)
	{
		if(oldbody[x] === "" || oldbody[x] === " ")
			continue;
		nextpos = GetNextStringPosition(oldbody[x], newbody, nextpos);
		if (nextpos < 0)
			return;
	}
	console.log("Queuing message for deletion (" + oldmsg.id() + "): " + oldmsg.subject());
	oldmsg.toDelete = true;
}

// Currently, this doesn't really verify the attachments.
//		It takes a good guess. It would take a resources to do this accurately
function CompareAttachments(nAtts, oAtts)
{
	for(let x = 0; x < oAtts.length; x++)
	{
		var oAtt = oAtts[x];
		if(oAtt.downloaded && oAtt.fileSize() > 1)
		{
			var nAtt = FindAttachment(nAtts, oAtt.name());
			if(nAtt == null || nAtt.fileSize() != oAtt.fileSize())
				return false;
		} 
	}
	return true;
}

// Returns the attachment if it finds it, or returns -1
function FindAttachment(atchmnts, name)
{
	for(let x = 0; x < atchmnts.length; x++)
	{
		if(atchmnts[x].name() === name)
			return atchmnts[x];
	}
	return null;
}

function GetNextStringPosition(oldstring, newarray, startpos)
{
	for(let x = startpos; x < newarray.length; x++)
	{
		if(newarray[x].includes(oldstring))
			return x+1;
	}
	return -1;
}                              ?jscr  ??ޭ