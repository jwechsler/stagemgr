class Notifier < ActionMailer::Base
  
  def order_notification(order)
    recipients order.address.email
    from       "boxoffice@theaterwit.org"
    subject    order.contains_flex_pass? ? "Your Theater Wit FlexPass is on it's way" : "Your ticket order for #{order.performance.production.name}" 
    body       order.contains_flex_pass? ? %Q(
Thanks so much for your FlexPass order.  We are processing your request and you should receive your FlexPass in the mail in the next 5-7 business days.

Once you get your FlexPass, you'll see a code that you can use online and at our box office to get tickets to any performance here at Theater Wit, subject to ticket availabilty.  Online, you can choose "FlexPass" as your payment type and just enter your code from your web browser.  At our box office, you can present your card and we will be happy to redeem it for tickets.  Keep in mind that a FlexPass reservation, once made, is subject to the same restrictions regarding cancellation and refunds as any normal ticket.

Your FlexPass is good for 18 months from date of issuance, and you can use it for any combination of shows you want.  Purchase 10 tickets all to the same evening, come twice with a friend, and once with a group, or just come and see a show every weekend for the next 2 1/2 months.  It's up to you.

Thank you for supporting Theater Wit and the many storefront theaters that make our home so special.  If you have any questions, please call our box office at 773-975-8150.

Thanks and we'll see you at the theatre!

The Staff at Theater Wit

) : %Q(
Thanks so much for your order.  We have #{order.ticket_quantity} ticket#{order.ticket_quantity > 1 ? 's' : ''} reserved for the #{order.performance.performance_time.strftime('%l:%M %p')} performance on #{order.performance.performance_date.strftime('%A, %B %d')} of #{order.performance.production.name} at Theater Wit under your name.  The total charge was $#{'%0.2f' % order.total}. Your tickets will be available at the box office ninety minutes before curtain.  Here's some handy stuff you'll want to know:

Getting Here

Theater Wit is located at 1229 W Belmont, between Southport and Racine.  We are accessible by "L" at the Belmont stop for the red, brown and purple lines four blocks east of us.  The 77 CTA bus also drops you on our doorstep.  If you will be driving, we do offer parking, but recommend you arrive early as it can fill up.

Pre-show Dining Recommendations

Cooper's (773.929.2667) is directly across the street, and features an excellent bbq and sandwich menu, along with some tasty vegetarian options.  Parking is complimentary if you dine at Cooper's.

Seating and Admission

All seating is general admission.  Each show opens it's doors 25 minutes before curtain time. Our houses are intimate with excellent sightlines, but if you are concerned, you may want to show up on the earlier side for your pick of seats.  If you have any special seating needs (handicapped/wheelchair accessible, groups over 15), please call us at 773-975-8150 and we'll make sure you're taken care of.

Please note that late seating is often NOT AVAILABLE for shows.  Please make plans to be at the theater at least ten minutes before curtain to avoid tears and recriminations.

Bar

Theater Wit has a wine and chocolate bar.  We feature handmade chocolates by local artisans and three wine selections every evening.  There are also soft drinks, local beers, well drinks and a cocktail of the month available.

Post-show

You are welcome to stay and finish your drinks and evening with us at Theater Wit.  After every show we offer complimentary coffee and snacks in our bar. Stay, meet the artists and each other.

And The Obligatory Legal Speak at the End of Emails

Please remember that your tickets are NON-REFUNDABLE and NON-EXCHANGEABLE.  We will do our best to accomodate last-minute changes but we reserve the right to let your seats wither on the vine, as it were.

)
  end

end
