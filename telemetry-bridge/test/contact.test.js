import test from 'node:test';
import assert from 'node:assert/strict';
import { ContactService, validateContact } from '../contact.mjs';

const recipients=['one@example.org','two@example.org'];
const mailEnv={CONTACT_FROM:'verified@example.org',CONTACT_RECIPIENTS:recipients.join(',')};
const body={name:'Review visitor',email:'visitor@example.org',message:'Please share the project documentation.'};
const request=(headers={})=>({headers:{host:'project.example',origin:'https://project.example','content-type':'application/json',...headers},socket:{remoteAddress:'127.0.0.1'}});
test('contact validates email, names, message limits, and rejects header injection',()=>{
  assert.deepEqual(validateContact(body),body);
  for(const patch of [{email:'invalid'},{email:'visitor@example.org\r\nBcc: attacker@example.org'},{name:'Name\nBcc: injected'},{message:'   '},{message:'a'.repeat(5001)},{website:'spam'}])assert.throws(()=>validateContact({...body,...patch}),error=>[400,422].includes(error.statusCode));
});
test('contact permits only same-origin JSON and rate limits attempts without trusting forwarded IPs',()=>{
  let time=0;const service=new ContactService({env:{CONTACT_ORIGIN:'https://project.example'},now:()=>time});
  assert.throws(()=>service.authorize(request({origin:'https://other.example'})),{statusCode:403});
  assert.throws(()=>service.authorize(request({'content-type':'text/plain'})),{statusCode:415});
  for(let i=0;i<5;i++)service.authorize(request({'x-forwarded-for':`198.51.100.${i}`}));
  assert.throws(()=>service.authorize(request()),{statusCode:429});
  time=900001;assert.doesNotThrow(()=>service.authorize(request()));
});
test('contact addresses only the configured recipients and uses visitor as Reply-To only',async()=>{
  const messages=[];
  const service=new ContactService({env:mailEnv,transport:{sendMail:async message=>{messages.push(message);return{accepted:[...recipients]};}}});
  const result=await service.send({...body,to:'untrusted@example.org',from:'forged@example.org',attachments:['/private/file']});
  assert.deepEqual(result,{accepted:true});assert.equal(messages.length,1);
  assert.deepEqual(messages[0].to,recipients);
  assert.equal(messages[0].from.address,'verified@example.org');assert.equal(messages[0].replyTo.address,body.email);
  assert.equal(messages[0].attachments,undefined);assert.ok(messages[0].text.includes(body.message));
});
test('contact never reports success without SMTP configuration or after rejection',async()=>{
  await assert.rejects(new ContactService({env:{}}).send(body),{statusCode:503});
  const transportWithoutRecipients={sendMail:async()=>assert.fail('No recipients are configured')};
  await assert.rejects(new ContactService({env:{CONTACT_FROM:mailEnv.CONTACT_FROM},transport:transportWithoutRecipients}).send(body),{statusCode:503});
  for(const transport of [{sendMail:async()=>{throw Error('Secret provider credentials');}},{sendMail:async()=>({accepted:recipients.slice(0,1)})}]){
    const service=new ContactService({env:mailEnv,transport});
    await assert.rejects(service.send(body),error=>error.statusCode===502&&!error.message.includes('Secret'));
  }
});
