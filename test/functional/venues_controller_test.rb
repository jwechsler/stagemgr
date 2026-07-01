require 'test_helper'

class VenuesControllerTest < ActionController::TestCase
  test 'should get now_playing' do
    get :now_playing
    assert_response :success
  end

  test 'should get offtime_now_playing' do
    get :offtime_now_playing
    assert_response :success
  end

  test 'should get primetime_up_next' do
    get :primetime_up_next
    assert_response :success
  end

  test 'should get offtime_up_next' do
    get :offtime_up_next
    assert_response :success
  end
end
